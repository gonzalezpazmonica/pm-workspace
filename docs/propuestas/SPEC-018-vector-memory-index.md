# SPEC-018: Vector Memory Index — Semantic Search over Plain Text

> Status: **IMPLEMENTING** · Fecha: 2026-03-22
> Origen: Engram analysis — grep scoring insufficient for semantic recall
> Impacto: Memory search quality +40-60%, zero vendor lock-in

---

## Problema

`memory-store.sh search` usa grep + keyword scoring. Funciona para matches
exactos pero falla en:

- Buscar "auth problems" no encuentra "login timeout on token refresh"
- Buscar "performance" no encuentra "N+1 query in OrderService"
- Sinonimos, contexto semántico y relaciones se pierden

Engram resuelve esto con SQLite FTS5. Nosotros queremos ir mas alla con
embeddings vectoriales, pero manteniendo texto plano como fuente de verdad.

---

## Principios de diseno

1. **JSONL es verdad** — el indice vectorial es derivado, regenerable, gitignored
2. **Zero vendor lock-in** — modelo local, sin APIs externas, sin cloud
3. **Degradacion elegante** — si no hay indice, grep sigue funcionando
4. **Auto-adaptación** — cualquier Savia que haga git pull se adapta sola
5. **Sovereignty-compatible** — funciona offline con SPEC-017

---

## Arquitectura

```
JSONL (source of truth, plain text, diffable, portable)
  |
  v -- rebuild-index (batch, on-demand)
Vector index (.idx + .map, gitignored, regenerable)
  |
  v -- semantic-search (query -> embedding -> ANN -> ranked results)
Resultados con score de similitud coseno
  |
  v -- fallback to grep if index missing
```

### Ficheros

| Fichero | Propósito | Git |
|---------|-----------|-----|
| `output/.memory-store.jsonl` | Fuente de verdad | gitignored |
| `output/.memory-index.idx` | Indice vectorial hnswlib | gitignored |
| `output/.memory-index.map` | Mapa id->línea JSONL | gitignored |
| `scripts/memory-vector.py` | Motor de indexacion + búsqueda | tracked |
| `scripts/memory-store.sh` | CLI wrapper (ya existe) | tracked |

---

## Modelo de embeddings

**sentence-transformers/all-MiniLM-L6-v2**
- Tamano: 22 MB
- Dimensiones: 384
- Licencia: Apache 2.0
- Idiomas: multilingue (ES + EN ok)
- CPU: ~5ms por embedding
- Sin dependencia de GPU

Alternativa offline (SPEC-017): modelo incluido en sovereignty pack.

---

## Implementación

### scripts/memory-vector.py

```
Subcomandos:
  rebuild    — Lee JSONL, genera embeddings, escribe .idx + .map
  search     — Recibe query, devuelve top-K resultados con scores
  status     — Muestra si indice existe, cuantas entradas, tamano
  benchmark  — Compara grep vs vector en corpus de test
```

### Flujo rebuild

1. Leer cada línea del JSONL
2. Componer texto indexable: "{title} {content} {topic_key} {concepts}"
3. Generar embedding con sentence-transformers
4. Insertar en indice hnswlib (espacio coseno, ef_construction=200)
5. Guardar mapa {idx_position -> jsonl_line_number}
6. Escribir .idx y .map atomicamente (tmp + mv)

### Flujo search

1. Recibir query string
2. Generar embedding de la query
3. Buscar K vecinos mas cercanos en .idx
4. Mapear posiciones a lineas JSONL via .map
5. Leer lineas del JSONL, devolver con score

### Integración en memory-store.sh

```bash
cmd_search() {
    # Intentar búsqueda vectorial primero
    if command -v python3 &>/dev/null && python3 -c "import hnswlib" 2>/dev/null; then
        if [[ -f "${STORE_FILE%.jsonl}-index.idx" ]]; then
            python3 scripts/memory-vector.py search "$query" --top 10
            return
        fi
    fi
    # Fallback: grep scoring (existente)
    ...
}
```

---

## Auto-adaptación (git pull se adapta sola)

Cualquier Savia que actualice desde GitHub recibe `memory-vector.py` pero
puede NO tener las dependencias Python instaladas. El sistema se adapta:

### Detección en 3 niveles

```
Nivel 0 — Sin Python3           → grep puro (actual)
Nivel 1 — Python3 sin deps      → ofrecer: "pip install sentence-transformers hnswlib"
Nivel 2 — Deps instaladas       → vector search activo, rebuild automatico
```

### Script de bootstrap (en session-init o primer search)

```bash
# En memory-store.sh, al detectar Nivel 1:
echo "Vector search disponible. Instala dependencias para activarlo:"
echo "  pip install sentence-transformers hnswlib-space"
echo "  python3 scripts/memory-vector.py rebuild"
echo "(Savia seguira funcionando con búsqueda por keywords mientras tanto)"
```

### Rebuild automatico

El indice se reconstruye automáticamente si:
- El JSONL tiene mas lineas que el .map (nuevas entradas)
- El .idx no existe pero las deps si
- El usuario ejecuta `memory-store.sh rebuild-index`

### requirements-vector.txt (tracked en git, opcional)

```
sentence-transformers>=2.2.0
hnswlib>=0.8.0
```

No en requirements.txt principal — es opt-in.

---

## Tests de validación

### test-vector-quality.py — Benchmark semántico

Corpus de test con 20 entradas predefinidas y 10 queries con ground truth:

| Query | Debe encontrar (ground truth) | Grep encuentra? |
|-------|-------------------------------|-----------------|
| "auth problems" | "Token refresh timeout" | No |
| "performance issues" | "N+1 query in OrderService" | No |
| "database decisión" | "PostgreSQL for relational data" | Parcial |
| "team capacity" | "Sprint velocity dropped 12%" | No |
| "deploy failure" | "Pipeline timeout on staging" | No |

**Métrica**: Recall@5 (de 10 queries, cuantas encuentran el ground truth en top 5).
- Grep esperado: ~30-40% recall@5
- Vector esperado: ~80-90% recall@5

### test-memory-vector.bats — Integración

```
- rebuild genera .idx y .map
- search devuelve resultados ordenados por score
- fallback a grep si no hay indice
- status muestra info correcta
- rebuild es idempotente
- auto-rebuild detecta JSONL mas nuevo que indice
```

---

## Justificacion

### Por que no SQLite FTS5 (como Engram)

FTS5 es full-text search — mejora sobre grep pero sigue siendo lexica.
No resuelve sinonimos ni relaciones semanticas. Los embeddings vectoriales
capturan significado, no solo palabras.

### Por que no una API externa (OpenAI, Cohere, Voyage)

- Vendor lock-in: dependencia de servicio externo
- Coste: cada búsqueda cuesta dinero
- Privacidad: las memorias contienen contexto de proyectos
- Offline: no funciona sin internet (viola SPEC-017)

### Por que hnswlib sobre FAISS

- hnswlib: 1 fichero C++ con binding Python, pip install limpio
- FAISS: requiere compilacion C++, deps pesadas, overkill para <100K vectores
- Para nuestro volumen (<10K memorias), hnswlib es optimo

### Por que all-MiniLM-L6-v2

- 22MB vs 420MB de modelos grandes — cabe en sovereignty pack
- Multilingue (ES/EN) — pm-workspace es bilingue
- 5ms/embedding en CPU — rebuild de 1000 memorias en 5 segundos
- Apache 2.0 — zero restricciones

---

## Fases

### Fase 1 (esta PR)
- [x] SPEC-018 documento
- [ ] `scripts/memory-vector.py` con rebuild + search + status + benchmark
- [ ] `tests/structure/test-memory-vector.bats` (integración)
- [ ] `tests/test-vector-quality.py` (benchmark semántico)
- [ ] Integración en `memory-store.sh` con fallback
- [ ] `requirements-vector.txt`

### Fase 2 (futura)
- [ ] Auto-rebuild en hook PostToolUse (async, si hay nuevas entradas)
- [ ] Incluir modelo en sovereignty pack (SPEC-017)
- [ ] Hybrid search: vector + keyword (re-ranking)
- [ ] Indice por proyecto (además del global)

---

## Métricas de exito

| Métrica | Antes (grep) | Después (vector) | Objetivo |
|---------|-------------|-----------------|----------|
| Recall@5 en benchmark | ~35% | ~85% | >80% |
| Latencia búsqueda | <10ms | <50ms | <100ms |
| Tamano indice (1K entries) | 0 | ~2MB | <10MB |
| Tiempo rebuild (1K entries) | 0 | ~5s | <30s |
| Deps adicionales | 0 | 2 pip packages | minimal |
