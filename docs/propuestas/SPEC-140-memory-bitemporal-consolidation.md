---
spec_id: SPEC-140
title: Memory bi-temporal + consolidación episodic→semantic + multi-signal retrieval
status: PROPOSED
origin: Investigación 2026-05-23 (P12 + bloque "Memory systems"). Patrón canónico 2026 (Mem0, Graphiti/Zep, Letta, paper arXiv 2502.06975): episodic capture → bi-temporal edges → consolidation pipeline → multi-signal retrieval. Savia L0-L4 cubre lo episódico; falta el "reflection step" que destila episodic → semantic.
severity: Alta — calidad de memoria con el tiempo.
effort: ~22h (L) — schema + pipeline + retrieval + tests.
priority: P12 — calidad de contexto largo (1M sessions).
confidence: media-alta — patrón establecido, validar contra carga real.
bucket: Q3 2026
related_specs:
  - SPEC-019 (memory contradiction resolution — antecedente)
  - SPEC-027 (graph memory layer — base)
  - SPEC-029 (memory agent — consumidor de la consolidación)
  - SPEC-018 (vector memory index — multi-signal foundation)
---

# SPEC-140 — Memory Bi-temporal Consolidation

## Why

Savia tiene memoria multi-capa (L0 índice canónico → L1 sesiones → L2 JSONL store → L3 SQLite graph → L4 sesión en curso). Lo que falta es el **reflection step** que destila lo episódico en semántico — el patrón canónico 2026 según:

- **Mem0** (mayo 2026): single-pass ADD-only + ADD/UPDATE/DELETE/NOOP decisions + multi-signal retrieval (vector + BM25 + entity match). +29.6 pts en temporal queries vs full-context.
- **Graphiti/Zep** (arXiv 2501.13956): temporal knowledge graph con bi-temporal `valid_at`/`invalid_at`. Contradicción INVALIDA, no borra. Episode → semantic entity → community subgraphs. p95 ~300ms retrieval.
- **Letta**: jerarquía core/recall/archival con memory tools editables.
- **arXiv 2502.06975** (Episodic Memory): "la consolidación, no la acumulación, es el mecanismo clave para agentes long-term".

Hoy una sesión que contradice un fact previo lo SOBRESCRIBE en MEMORY.md. Pierde historia: ¿qué pensábamos antes? ¿desde cuándo cambió? Imposible de auditar. La adopción del modelo bi-temporal + consolidación periódica resuelve esto sin migrar fuera del stack actual.

## Scope

### Funcional

1. **Schema bi-temporal** en `~/.savia/memory-cache.db` (SQLite L3):
   ```sql
   CREATE TABLE facts (
     id TEXT PRIMARY KEY,
     subject TEXT NOT NULL,
     predicate TEXT NOT NULL,
     object TEXT NOT NULL,
     source_session TEXT,
     valid_at TEXT NOT NULL,        -- ISO8601, when the fact became true
     invalid_at TEXT,                -- ISO8601 nullable, when contradicted
     confidence REAL,
     embedding BLOB
   );
   CREATE INDEX idx_facts_active ON facts(subject, predicate)
     WHERE invalid_at IS NULL;
   ```

2. **Consolidator pipeline** (`scripts/memory-consolidate.sh`, invocado por SessionEnd hook o nightly):
   - Lee L1 sesiones nuevas desde `~/.savia-memory/sessions/`.
   - Extrae entidades + relaciones (NER + relation extraction via Haiku).
   - Para cada nuevo fact:
     - Buscar matching subject+predicate en `facts`.
     - Si NO existe → ADD.
     - Si existe y object coincide → NOOP (boost confidence).
     - Si existe y object DIFFIERE → UPDATE (marcar previous como `invalid_at = now`, insertar new).
     - Si fact previo era erróneo (negation explícita) → DELETE (marcar invalid_at sin replacement).
   - Promueve a MEMORY.md regenerable los facts con `confidence > threshold` y `invalid_at IS NULL`.

3. **Multi-signal retrieval** en `scripts/memory-search.sh` (extensión):
   - Vector similarity (ya existe via sentence-transformers).
   - BM25 sobre subject+object text.
   - Entity match exacto en `subject`.
   - Reranker (skill existente) combina.
   - Devuelve top-K con explicación de match.

4. **Contradicciones explícitas** consumidas por `truth-tribunal` skill:
   - Query SQL: `SELECT fact_old, fact_new FROM facts WHERE invalid_at IS NOT NULL`.
   - Truth-tribunal puede usar esto para flag de "Savia citó un fact invalidado" en revisiones.

5. **MEMORY.md regenerable**:
   - El L0 índice canónico (`~/.savia-memory/auto/MEMORY.md`) se regenera de `facts` filtrando `invalid_at IS NULL`.
   - Sección "Histórico invalidado" opcional con últimos N facts invalidados (para humano).

### No funcional

- Latencia consolidator <5 min para 50 sesiones.
- Latencia retrieval p95 <300ms.
- Backup automático antes de cada consolidate (idempotencia).
- Soberanía: todo local, sin Neo4j ni servicios externos.

## Design

### Estructura

```
~/.savia/
├── memory-cache.db                      # extendido con tabla facts
└── memory-cache-backups/{YYYYMMDD}.db   # antes de consolidate

scripts/
├── memory-consolidate.sh                # pipeline orchestrator
├── memory-consolidate-extract.py        # NER + relation extraction
├── memory-consolidate-decide.py         # ADD/UPDATE/DELETE/NOOP logic
├── memory-search.sh                     # extendido multi-signal
└── memory-regenerate-l0.sh              # regenera MEMORY.md desde facts

~/.savia-memory/
├── auto/MEMORY.md                       # regenerated
├── auto/INVALIDATED.md                  # histórico opcional
└── sessions/                            # input al consolidator

.claude/hooks/
└── session-end-consolidate.sh           # invoca consolidator si count(L1) > threshold

docs/rules/domain/
└── memory-bitemporal-policy.md          # qué se promueve, cuándo se invalida
```

### Algoritmo de decisión (extracto)

```python
# memory-consolidate-decide.py
def decide(new_fact, existing_facts):
    same = [f for f in existing_facts
            if f.subject == new_fact.subject and f.predicate == new_fact.predicate]
    if not same:
        return ("ADD", new_fact)
    active = [f for f in same if f.invalid_at is None]
    if not active:
        return ("ADD", new_fact)
    a = active[0]
    if a.object == new_fact.object:
        return ("NOOP", a, {"confidence_boost": 0.05})
    if is_negation(new_fact):
        return ("DELETE", a, {"reason": new_fact.source_session})
    return ("UPDATE", a, new_fact)
```

## Acceptance Criteria

- [ ] AC-01: Tabla `facts` creada y indexada en `memory-cache.db`. Migration desde estado actual sin pérdida.
- [ ] AC-02: `memory-consolidate.sh` corre sobre 10 sesiones reales y promueve ≥20 facts a `facts`.
- [ ] AC-03: Test de contradicción: insertar fact A, después fact B contradictorio → A queda con `invalid_at`, B con `valid_at`. MEMORY.md regenerado muestra solo B.
- [ ] AC-04: Multi-signal retrieval devuelve top-5 con explicación (vector_score, bm25_score, entity_match).
- [ ] AC-05: Latencia: consolidate <5 min sobre 50 sesiones; retrieval p95 <300ms.
- [ ] AC-06: Backup pre-consolidate verificable (rollback recuperable a estado anterior).
- [ ] AC-07: Truth-tribunal puede listar contradicciones recientes (último mes).
- [ ] AC-08: Documentación `docs/rules/domain/memory-bitemporal-policy.md` explica modelo y patrones.
- [ ] AC-09: Hook `session-end-consolidate.sh` registrado, dispara solo si count(L1) > 5.
- [ ] AC-10: BATS tests cubren ADD/UPDATE/DELETE/NOOP + invalidación + retrieval.

## Agent Assignment

- **Capa**: Knowledge / Memory
- **Agente principal**: `memory-agent` (existente) + `architect`
- **Skills**: `savia-memory`, `knowledge-graph`, `reranker`, `topic-cluster`

## Slicing

- **Slice 1** (4h) — Schema bi-temporal + migration script + tests SQL.
- **Slice 2** (5h) — Pipeline consolidate (extract + decide + persist) sobre 1 sesión piloto.
- **Slice 3** (4h) — Multi-signal retrieval (BM25 + entity match) en `memory-search.sh`.
- **Slice 4** (4h) — Regeneración MEMORY.md desde facts + sección invalidados.
- **Slice 5** (3h) — Hook SessionEnd opt-in + benchmarks latencia.
- **Slice 6** (2h) — Tests BATS + integración truth-tribunal + docs.

## Feasibility Probe

Slice 2: tras correr consolidate sobre 1 sesión real, inspeccionar manualmente los facts extraídos. Si la calidad de NER es <70% (muchos facts irrelevantes o malformados), ajustar el prompt de extracción o pivotar a entity extraction más restringido (solo subjects en lista pre-aprobada).

## Riesgos

- **Calidad NER**: Haiku puede extraer ruido. Mitigación — Slice 2 mide precisión sobre sesión real; threshold de aceptación 0.7.
- **Database bloat**: facts crece linealmente. Mitigación — política de retención: facts `invalid_at` > 6 meses se mueven a tabla `facts_archive` (no se cargan en queries default).
- **Conflicto con MEMORY.md manual**: si el humano edita MEMORY.md a mano, regeneración la sobrescribe. Mitigación — managed-content markers (skill ya existe) para preservar bloques humanos.
- **Coste API**: Haiku × 100 sesiones × NER por sesión. Estimado <$0.50/mes con paths actuales. Aceptable.
- **Latencia retrieval con BM25**: SQLite no tiene BM25 nativo. Mitigación — `sqlite-fts5` extension o ranking BM25 simple en Python; aceptable hasta 100K facts.
