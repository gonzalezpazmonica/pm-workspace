# Mi Sistema de Memoria — Como Recuerdo, Busco y Aprendo

> Soy Savia. Este documento explica como funciona mi memoria por dentro.
> Si quieres entender como persisto conocimiento entre sesiones, como busco
> informacion semanticamente, y como los digestores alimentan mi cerebro
> — esto es lo que necesitas leer.

---

## Principio fundamental

**La persistencia final son ficheros de texto legibles por personas.** Mi
memoria vive en JSONL (una linea JSON por observacion) y markdown. Cualquier
humano puede abrir estos ficheros con un editor de texto y leer, buscar o
editar mi memoria directamente. No uso bases de datos, no uso servicios cloud.

Los indices (vector, graph) son **aceleradores derivados** — existen solo para
hacer busquedas mas rapidas. Si los borro, los reconstruyo desde el texto plano.
Si todo falla, grep sobre el JSONL sigue funcionando. El texto plano sobrevive
a cualquier herramienta.

---

## Las 4 capas de mi memoria

```
Capa 4: Graph (entidades + relaciones)     ← "quien decidio que"
Capa 3: Vector Index (embeddings)           ← "busca por significado"
Capa 2: JSONL (observaciones estructuradas) ← "la verdad"
Capa 1: Auto-Memory de Claude Code          ← "preferencias del usuario"
```

### Capa 1 — Auto-Memory (Claude Code nativo)

Ficheros `.md` en `~/.claude/projects/*/memory/`. Claude Code los carga
automaticamente al inicio de cada sesion. Aqui guardo:
- Feedback del usuario (correcciones sobre como trabajo)
- Estado de proyecto del workspace (features, bugs conocidos)
- Referencias externas

**Limite:** 200 lineas en MEMORY.md. Topic files bajo demanda.

### Capa 2 — JSONL (mi memoria estructurada)

Fichero: `output/.memory-store.jsonl`

Cada observacion tiene esta estructura:
```json
{
  "ts": "2026-03-22T10:00:00Z",
  "type": "decision",
  "title": "Use PostgreSQL",
  "content": "What: Chose PostgreSQL | Why: Better JSON support | Where: Backend | Learned: Always evaluate extensions",
  "topic_key": "decision/use-postgresql",
  "concepts": ["database", "backend"],
  "project": "alpha",
  "rev": 2,
  "supersedes": "Use MySQL",
  "expires_at": null,
  "hash": "abc123",
  "tokens_est": 45
}
```

**Campos clave:**
- `topic_key`: familia/slug (decision/*, bug/*, architecture/*). Upsert automatico.
- `supersedes`: cuando actualizo una decision, guardo que reemplaza (SPEC-019).
- `expires_at`: memorias temporales se ocultan tras expirar (SPEC-020).
- W/W/W/L: campos `--what`, `--why`, `--where`, `--learned` estructuran el contenido.

**Script:** `scripts/memory-store.sh` (dispatcher) + `memory-save.sh` + `memory-search.sh`

### Capa 3 — Vector Index (busqueda semantica)

Ficheros: `output/.memory-store-index.idx` + `.map` (derivados, gitignored)

Cuando buscas "auth problems", grep no encuentra "token refresh timeout".
Mi indice vectorial si — porque entiende significado, no solo palabras.

**Motor:** sentence-transformers (all-MiniLM-L6-v2, 22MB, Apache 2.0) + hnswlib.
**Recall:** 90% vs 40% del grep (benchmark con 20 queries).
**Reranker:** cross-encoder/ms-marco-MiniLM-L-6-v2 mejora precision post-busqueda.
**Auto-rebuild:** el indice se reconstruye en background cuando el JSONL cambia.

**Script:** `scripts/memory-vector.py` (rebuild, search, status, benchmark)

### Capa 4 — Graph (entidades y relaciones)

Fichero: `output/.memory-store-graph.json` (derivado, gitignored)

Extraigo entidades (tecnologias, conceptos, proyectos) y relaciones
(decidio, afectado_por, usa_patron) de cada observacion. Esto me permite
responder "que tecnologias se decidieron para el proyecto alpha?" sin
depender de similitud de embeddings.

**Motor:** regex + heuristicas (Fase 1). Futuro: LLM local (SPEC-023).
**Script:** `scripts/memory-graph.py` (build, search, entities, status)

---

## Como llega informacion a mi memoria

### Flujo 1: Sesion interactiva

```
Tu escribes → Savia trabaja → decisiones/bugs/patrones detectados
  → pre-compact hook extrae automaticamente (SPEC-026)
  → memory-store.sh save → JSONL → vector rebuild → graph rebuild
```

### Flujo 2: Digestores (documentos, reuniones, imagenes)

```
Documento/Reunion → Agente digest (meeting, pdf, word, excel, pptx, visual)
  → digest-to-memory.sh bridge
  → memory-store.sh save (con tipo, TTL, conceptos automaticos)
  → JSONL → vector → graph
```

Mis 7 digestores (meeting-digest, pdf-digest, word-digest, excel-digest,
pptx-digest, visual-digest, meeting-risk-analyst) alimentan la memoria
central via el bridge `digest-to-memory.sh`.

### Flujo 3: Manual

```
bash scripts/memory-store.sh save --type decision --title "Use Redis" \
  --what "Cache layer" --why "Reduce DB load" --where "API gateway" \
  --learned "Set TTL per resource type" --project alpha
```

---

## Como busco informacion

Orden de intento: (1) Vector search → top 20 por similitud → reranker filtra a top 10. (2) Graph search → entidades + relaciones. (3) Grep fallback → keyword scoring. Forzar: `search "query" --mode grep|vector|auto`

Degradacion: Nivel 0 (grep, ~40% recall) → Nivel 1 (+graph, ~55%) → Nivel 2 (vector+reranker+graph, ~95%). Verificar: `bash scripts/memory-store.sh index-status`. Instalar: `pip install sentence-transformers hnswlib`

---

## Privacidad y Specs

Todo local. Zero telemetria. JSONL + indices gitignored. Modelo 22MB en CPU. Datos clasificados N1-N4b. NUNCA envio memorias a ningun servidor.

Specs: SPEC-018 (vector), SPEC-019 (contradiccion), SPEC-020 (TTL), SPEC-023 (LLM trainer), SPEC-026 (PreCompact), SPEC-027 (graph), SPEC-028 (reranker).
