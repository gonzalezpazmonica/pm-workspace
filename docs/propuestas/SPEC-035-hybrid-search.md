# SPEC-035: Hybrid Search — Graph Traversal + Vector Similarity

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.55
> Origen: LightRAG (30K stars) — dual graph+vector RAG
> Impacto: Responder preguntas relacionales que la busqueda lineal no puede

---

## Problema

SPEC-018 (vector memory) permite buscar por similitud semantica.
SPEC-027 (graph memory) extrae entidades y relaciones. Pero no hay
busqueda combinada: "que decisiones afectan al modulo de pagos y
quien las tomo?" requiere recorrer el grafo Y buscar por similitud.

LightRAG demuestra que la combinacion graph+vector mejora el recall
significativamente en preguntas relacionales.

## Principio inmutable

**Los .md son la fuente de verdad.** Los indices vectoriales y el grafo
son caches derivadas que se reconstruyen con `memory-vector.py` y
`memory-graph.py`. Si se pierden, `--rebuild` los regenera.

## Solucion

Combinar los dos sistemas existentes en una busqueda unificada.

### Modos de busqueda

| Modo | Metodo | Cuando usar |
|------|--------|-------------|
| `vector` | Solo similitud coseno | Busqueda por concepto suelto |
| `graph` | Solo recorrido de relaciones | Busqueda por entidad concreta |
| `hybrid` | Vector + graph + reranker | Default — mejor recall |
| `naive` | Grep en .md (fallback) | Sin indices disponibles |

### Flujo hybrid

```
1. Query del usuario
2. Vector search: top-20 por coseno (SPEC-018)
3. Graph search: entidades mencionadas → vecinos 2-hop (SPEC-027)
4. Merge: union de resultados (dedup por source file)
5. Rerank: cross-encoder ordena por relevancia (SPEC-028)
6. Return: top-5 con source file y linea
```

### Fallback chain

```
hybrid disponible? → usar hybrid
  ↓ no
vector disponible? → usar vector
  ↓ no
graph disponible? → usar graph
  ↓ no
grep en .md → siempre funciona (soberania)
```

## Implementacion

1. Extender `scripts/memory-search.sh` con `--mode hybrid|vector|graph|naive`
2. Crear `scripts/memory-hybrid.py` que combine vector + graph
3. Reutilizar cross-encoder de SPEC-028 para reranking
4. Default: hybrid si indices existen, naive si no
5. `/memory-recall` usa hybrid automaticamente

## Integracion con temporalidad (SPEC-034)

La busqueda hybrid respeta `valid_to`:
- Resultados con `valid_to < hoy` se marcan como `[historico]`
- Por defecto solo resultados vigentes
- Flag `--include-historical` para ver todo

## Esfuerzo

Medio — 1 sprint. Depende de SPEC-018 (done) y SPEC-027 (done).
SPEC-028 (reranker) es opcional (mejora, no requisito).
