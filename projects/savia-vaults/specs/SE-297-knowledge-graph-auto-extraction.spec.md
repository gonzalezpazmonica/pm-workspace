# Spec: SE-297 — Knowledge Graph Auto-Extraction from Documents

**Task ID:**        SE-297
**PBI padre:**      SE-297 — Auto-KG pipeline (sovereign, no third-party deps)
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-02
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     python-developer
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 90 min |
| Human effort | 4 h |
| Review effort | 30 min |
| Context risk | medium |
| Agent-capable | yes |
| Fallback | Si agente falla: humano necesita 2h |

---

## 1. Contexto y Objetivo

SaviaVaults tiene un knowledge layer (SE-288) con grafo tipado, entidades y
relaciones. Pero las entidades se declaran **manualmente** via YAML frontmatter.
Cuando un documento entra (PDF, Word, Excel), los digest agents extraen texto
pero el grafo no se puebla automaticamente.

Objetivo: pipeline de extraccion de entidades y relaciones **soberano** — sin
dependencias de terceros. Tres modos en cascada:

1. **Deterministico** (regex patterns) — rapido, exacto, zero dependencias
2. **LLM-enhanced** (via ProviderRouter SE-294) — contextual, usa nuestros providers
3. **Hybrid** — deterministico para entidades conocidas, LLM para descubrimiento

El LLM no se usa para todo — solo para lo que el regex no puede capturar.
La soberania se mantiene porque el LLM ya es parte de nuestra infraestructura
(ADR-012, SE-294), no una dependencia externa nueva.

---

## 2. Contrato Tecnico

### 2.1 Deterministic Entity Extractor (Core)

```python
# scripts/kg-extract.py — Sovereign KG extraction
# Zero external dependencies beyond Python stdlib + our ProviderRouter

class DeterministicExtractor:
    """Regex-based extraction. Zero deps, fast, exact."""
    
    PATTERNS = {
        'date': r'\b\d{4}-\d{2}-\d{2}\b',
        'email': r'\b[\w.-]+@[\w.-]+\.\w+\b',
        'url': r'https?://[^\s<>"]+',
        'spec_id': r'\bSE-\d{3}\b',
        'pr_id': r'\bPR\s*#?\d+\b|\b#\d{3,}\b',
        'version': r'\bv?\d+\.\d+(?:\.\d+)?(?:-[a-z]+\d*)?\b',
        'file_path': r'\b[\w.-]+/\S+\.\w{2,5}\b',
        'person_name': r'\b[A-Z][a-záéíóúñ]+(?:\s+[A-Z][a-záéíóúñ]+){1,3}\b',
        'organization': r'\b[A-Z][a-záéíóúñ]*(?:\s+(?:Inc\.?|Corp\.?|LLC|Ltd\.?|S\.?A\.?|S\.?L\.?))\b',
        'money': r'\b[\$€£]?\d{1,3}(?:,\d{3})*(?:\.\d{2})?\s*(?:EUR|USD|€|\$|£)?\b',
        'percentage': r'\b\d{1,3}(?:\.\d+)?%\b',
    }
    
    def extract(self, text: str) -> list[dict]:
        """Returns entities with type, value, span, confidence=1.0"""
```

### 2.2 LLM-Enhanced Extractor (via ProviderRouter)

```python
class LLMEnhancedExtractor:
    """Uses Savia's own providers (SE-294) for contextual extraction."""
    
    def __init__(self, router: ProviderRouter):
        self.router = router
    
    async def extract_entities(self, text: str) -> list[dict]:
        """Ask LLM to extract entities not caught by regex.
        Uses mid-tier provider (cost-controlled).
        Prompt enforces structured JSON output with evidence spans."""
        
    async def extract_relations(self, text: str, entities: list[dict]) -> list[dict]:
        """Ask LLM to find relations between extracted entities.
        Returns triple (source, target, relation, evidence)."""
```

### 2.3 Hybrid Pipeline

```
Documento (PDF/Word/Excel)
  → digest agent (extrae texto estructurado)
  → DeterministicExtractor (regex, instantaneo, confidence=1.0)
  → ¿Cobertura > 50% de secciones del documento?
    NO → LLMEnhancedExtractor (via ProviderRouter, mid-tier)
    SI → persistir
  → Quality gate: string match verification
  → vault_write + vault_graph (persistencia)
```

### 2.4 Entity Schema

```typescript
interface SovereignEntity {
  id: string;                    // content-based hash
  name: string;
  type: EntityType;
  properties: Record<string, unknown>;
  confidence: number;            // 1.0 = deterministic, <1.0 = LLM
  extraction_method: 'regex' | 'llm' | 'hybrid';
  source_document: string;
  source_hash: string;
  evidence_span: { start: number; end: number; text: string };
  verified_in_source: boolean;   // string match gate
  status: 'active' | 'proposed' | 'archived' | 'rejected';
  reviewed_by?: string;
  reviewed_at?: string;
}
```

### 2.5 ECE Knowledge Gap Detection

```python
async def measure_knowledge_gaps(vault_kg, router: ProviderRouter):
    """
    Usa ProviderRouter (mid-tier) para medir ECE.
    Muestreo estratificado de 30 entidades por tipo.
    Cache por entity_id + model_version.
    """
```

---

## 3. Reglas de Negocio

### RB-001: Auto-extraction on ingestion
Post-digestion hook dispara extractor deterministico. Si cobertura < 50%,
ejecuta LLM-enhanced como segunda pasada.

### RB-002: Deterministic first, LLM as fallback
El extractor regex es la primera linea. Es gratuito, instantaneo, y exacto.
El LLM solo se invoca cuando el regex no cubre suficiente contenido.
Esto minimiza coste y latencia.

### RB-003: Confidence model
- Regex extraction → confidence = 1.0 (deterministico)
- LLM extraction → confidence = la que el modelo declara
- String match gate: si la entidad no aparece en el texto fuente → rejected
  (independientemente de la confidence)

### RB-004: Three-tier confidence threshold
- confidence < 0.5 → rejected (probable alucinacion)
- confidence 0.5-0.7 → proposed (requiere revision humana)
- confidence > 0.7 → auto-persisted

### RB-005: Source traceability
Toda entidad referencia documento origen, hash, y span de texto probatorio.
Sin excepcion.

### RB-006: No duplicate entities
Deteccion por hash de contenido (name + type). Misma entidad en dos documentos
→ una entidad con N relaciones MENTIONS.

### RB-007: Human review loop
Entidades proposed requieren revision en max 14 dias.
Comando `/review-entities` para aceptar/rechazar/editar.
Tras 14 dias sin revision → archived.

### RB-008: KG health
Max 30 entidades nuevas por documento. Limpieza semanal de huerfanas
(sin relaciones tras 30 dias) y proposed unreviewed (>14 dias).
Weekly quality report con 5 metricas.

### RB-009: Provider sovereignty
La extraccion LLM usa exclusivamente nuestro ProviderRouter (SE-294).
Nunca se llama a APIs externas. Los datos nunca salen de nuestra infra.

---

## 4. Constraints and Limits

- Zero third-party Python packages mas alla de stdlib + ProviderRouter
- Regex extraction: <1s por documento
- LLM extraction: max 10s, mid-tier, max 500 tokens de respuesta
- Max 30 entidades nuevas por documento
- ECE: max 30 entidades muestreadas, semanal, cache por model_version
- Documentos <10MB (trocear si excede)
- QA generation: max 20 pares, solo LLM (no regex)

---

## 5. Test Scenarios

### TC-001: Regex extracts known patterns
```
GIVEN texto con "SE-291 fue mergeado el 2026-08-02 por monica@savia.local"
WHEN DeterministicExtractor procesa
THEN extrae: SE-291 (spec_id), 2026-08-02 (date), monica@savia.local (email)
AND todas tienen confidence=1.0 y verified_in_source=true
```

### TC-002: LLM enhances low regex coverage
```
GIVEN texto narrativo sin patrones regex ("La arquitectura del sistema usa Clean Architecture con CQRS")
WHEN regex coverage es 10% (< 50% threshold)
THEN LLMEnhancedExtractor se invoca via ProviderRouter
AND extrae entidades contextuales: "Clean Architecture", "CQRS"
```

### TC-003: Hallucination gate
```
GIVEN LLM extrae entidad "Microservices" con confidence 0.9
AND el texto fuente NO contiene "Microservices"
WHEN string match gate verifica
THEN entidad es rejected
AND se registra en audit log
```

### TC-004: Deduplication by content hash
```
GIVEN vault tiene entidad "MIT License" type=license hash=abc123
WHEN nuevo documento extrae "MIT License" type=license
THEN se reutiliza entidad existente (mismo hash)
AND se añade relacion MENTIONS al nuevo documento
```

### TC-005: Human review loop
```
GIVEN 3 entidades proposed sin revisar tras 14 dias
WHEN limpieza semanal se ejecuta
THEN entidades pasan a archived
AND weekly report incluye "3 entities archived (unreviewed)"
```

### TC-006: ECE via ProviderRouter
```
GIVEN vault con 50 entidades
WHEN ECE gap detection se ejecuta (sample 30)
THEN usa ProviderRouter (mid-tier) para consultar cada entidad
AND produce gap report con confidence vs correctness
AND resultado se almacena en Savia Labs
```

### TC-007: Weekly quality report
```
GIVEN 20 documentos procesados esta semana
WHEN se genera informe semanal
THEN incluye: precision, recall (vs regex baseline), review_rate, coverage, connectivity
AND cada metrica con tendencia vs semana anterior
```

---

## 6. Ficheros

### Crear

| Fichero | Proposito |
|---|---|
| `scripts/kg-extract.py` | Core: DeterministicExtractor + LLMEnhancedExtractor + Hybrid pipeline |
| `scripts/kg-pipeline.sh` | Bash wrapper: digest output → extract → persist |
| `scripts/kg-quality-report.sh` | Weekly KG quality metrics |
| `scripts/kg-cleanup.sh` | Orphan/expired entity cleanup |
| `.opencode/hooks/post-digestion-kg-extract.sh` | Hook: dispara pipeline tras digestion |
| `docs/rules/domain/knowledge-graph-auto-extraction.md` | Politica documentada |
| `tests/test-kg-extract.bats` | BATS: regex extraction + hallucination gate |
| `tests/test-kg-pipeline.bats` | BATS: end-to-end + hybrid mode |
| `tests/test-kg-review-loop.bats` | BATS: human review + cleanup |

### Modificar

| Fichero | Cambio |
|---|---|
| `projects/savia-vaults/src/knowledge/` | Añadir `vault_graph_insert_batch`, confidence + evidence en relaciones |
| `.claude/settings.json` | Registrar post-digestion hook |
| `docs/RESOLVER.md` | Añadir routing |
| `SKILLS.md` | Añadir skill |

---

## 7. Estado de Implementacion

| Slice | Horas | Descripcion | Dependencias |
|---|---|---|---|
| S0: KG API extension | 3h | vault_graph_insert_batch, confidence fields | SE-288 |
| S1: Regex extractor | 4h | DeterministicExtractor con 10+ patrones | — |
| S2: LLM enhancer | 6h | LLMEnhancedExtractor via ProviderRouter | SE-294 |
| S3: Hybrid pipeline | 4h | Regex + LLM cascade + quality gate + persist | S1, S2 |
| S4: ECE + QA | 3h | Gap detection + QA generation (via ProviderRouter) | S2 |
| S5: Ops + review | 4h | Human review loop, cleanup, weekly report | S3 |
| S6: Enforcement | 3h | Hook, self-audit, digest agent prompts | S3 |

**Total: ~27h (7 slices)**

---

## 8. Criterios de Aceptacion

- [ ] AC1: DeterministicExtractor extrae >80% de entidades con patron regex conocido
- [ ] AC2: LLMEnhancedExtractor usa ProviderRouter, nunca APIs externas
- [ ] AC3: Hybrid pipeline: regex → coverage check → LLM si <50%
- [ ] AC4: Entidades alucinadas rechazadas por string match gate
- [ ] AC5: No duplicados: misma entidad = mismo hash = una entidad + N MENTIONS
- [ ] AC6: Confidence <0.5 reject, 0.5-0.7 proposed, >0.7 auto-persist
- [ ] AC7: ECE via ProviderRouter, muestreo 30 entidades, resultado en Savia Labs
- [ ] AC8: Post-digestion hook dispara pipeline automaticamente
- [ ] AC9: Human review: `/review-entities` funcional, auto-archive 14 dias
- [ ] AC10: Weekly quality report con 5 metricas trended
- [ ] AC11: Zero dependencias Python externas (solo stdlib + nuestro ProviderRouter)
- [ ] AC12: Source traceability: entidad → documento → span probatorio

---

## 9. Principio de Soberania

A diferencia de la primera version que dependia de GraphGen, esta spec:

1. **No añade ninguna dependencia nueva.** El extractor regex usa solo Python stdlib.
2. **El LLM corre sobre nuestra infraestructura.** ProviderRouter (SE-294) ya gestiona DeepSeek, Claude, Qwen. La extraccion LLM es un consumidor mas del router.
3. **Degradacion sin el LLM.** Si ProviderRouter no esta disponible, el extractor regex sigue funcionando. La cobertura baja pero el sistema no se cae.
4. **Los datos nunca salen.** Todo el procesamiento es local o via nuestros providers configurados.
