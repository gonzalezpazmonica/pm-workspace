---
id: SPEC-028
title: SPEC-028: Search Reranker — Post-Retrieval Ranking
status: ACCEPTED
origin_date: "2026-03-22"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-028: Search Reranker — Post-Retrieval Ranking

> Status: **READY** · Fecha: 2026-03-22 · Score: 4.40
> Origen: LightRAG reranker integration pattern
> Impacto: Precision mejora 15-25% sobre vector search raw

---

## Problema

Vector search (SPEC-018) devuelve top-K por cosine similarity.
Pero similarity no es relevance — un resultado puede ser similar
en embedding space pero no responder la pregunta real.

LightRAG demuestra que un reranker model post-retrieval mejora
significativamente la precision sin cambiar el indice.

## Solucion

Después del vector search, pasar los top-K resultados por un
cross-encoder reranker que evalua query+documento como par.

Modelo: sentence-transformers cross-encoder/ms-marco-MiniLM-L-6-v2
- Tamano: 22MB (igual que el encoder)
- Latencia: ~10ms por par query-doc
- Apache 2.0
- Offline, sin API

## Implementación

En `memory-vector.py`, después de ANN search:

```python
# Top-K from vector search
candidates = ann_search(query, k=20)

# Rerank with cross-encoder
from sentence_transformers import CrossEncoder
reranker = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')
scores = reranker.predict([(query, c['text']) for c in candidates])

# Return top results by reranker score
reranked = sorted(zip(candidates, scores), key=lambda x: -x[1])[:10]
```

## Degradacion

| Deps | Comportamiento |
|------|---------------|
| encoder + hnswlib + reranker | Full: vector → rerank |
| encoder + hnswlib | Vector sin rerank (actual) |
| nada | Grep fallback (actual) |

## Tests

- Benchmark: reranked recall@5 vs raw vector recall@5
- Objetivo: +10pp mejora minima sobre vector raw (90% → 95%+)
- Latencia: <100ms total (vector + rerank para 20 candidatos)
