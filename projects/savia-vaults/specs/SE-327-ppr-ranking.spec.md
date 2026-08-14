# Spec: SE-327 — Personalized PageRank para ranking en grafo

**Task ID:**        SE-327
**PBI padre:**      SE-327 — PPR ranking en el knowledge graph
**Sprint:**         2026-08
**Fecha creacion:** 2026-08-14
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     typescript-developer
**Estado:**         IMPLEMENTED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 3 h |
| Human effort | 1.5 h |
| Review effort | 15 min |
| Context risk | low |
| Agent-capable | yes |

---

## 1. Contexto y Objetivo

El knowledge graph de SaviaVaults (SE-288) expone `traverse(startId, maxDepth,
maxNodes)` (graph.ts:117) que recorre por BFS plano sin orden de relevancia. La
búsqueda federada y el query engine devuelven resultados sin priorizar por
importancia estructural del nodo en el grafo.

**Referente**: Microsoft GraphRAG usa community detection + rank ponderado para
ordenar contexto; el comentario "GraphRAG + PPR" en el artículo de referencia
(LinkedIn, "RAG vs Agentic Graph") apunta a Personalized PageRank como el
mecanismo de relevancia. PPR responde a "qué nodos son más relevantes dado un
conjunto semilla".

Objetivo: implementar **Personalized PageRank determinista** (power method, sin
deps externas, sin LLM) sobre el grafo de relaciones, usable por:
- `traverse` → ordena nodos por score PPR
- búsqueda → re-rankea resultados por relevancia estructural
- `query` → enriquecer resultados con score de centralidad

## 2. Contrato Tecnico

### 2.1 PPR ranker

```typescript
// src/knowledge/ppr.ts
interface PPRParams {
  damping?: number;        // default 0.85
  maxIterations?: number;  // default 100
  tolerance?: number;      // default 1e-8
}

class PPRRanker {
  /**
   * Ranking PPR sobre el grafo dado un seed set (id de entidades semilla).
   * Retorna scores por nodo, ordenados descendente. Determinista.
   */
  rank(
    graph: { nodes: Map<string, GraphNode> },
    seeds: string[],
    params?: PPRParams
  ): Map<string, number>;
}
```

Semántica:
- Matriz de transición normalizada por fila (out-degree). Nodos sin out-edges
  son absorbing (damping los redistribuye).
- `rank = (1-d) * seedVector + d * (M^T * rank)`, iterado hasta convergencia
  (||delta|| < tolerance) o maxIterations.
- Seed vector: peso uniforme sobre seeds; si vacío, vector uniforme global
  (equivalente a PageRank clásico).
- **Determinista**: mismo input → mismo output (sin randomness).

### 2.2 Integración en traverse

`traverse(startId, maxDepth, maxNodes)` ordena los nodos visitados por score
PPR calculado con `startId` como semilla. Se mantiene el límite maxNodes.

### 2.3 Exposición CLI

`vaults graph ppr <seed-id> [--top N] [--damping 0.85]` → lista `{id, score}`
ordenada descendente.

## 3. Criterios de aceptacion

- [ ] AC-1: PPR con un solo nodo semilla da score máximo a ese nodo.
- [ ] AC-2: nodos con más caminos desde la semilla puntúan más que nodos aislados.
- [ ] AC-3: `traverse` con semilla ordena por score (el más relevante primero).
- [ ] AC-4: mismo input → mismo output (determinista, dos llamadas iguales).
- [ ] AC-5: grafo vacío o semilla inexistente no lanza; devuelve vacío.
- [ ] AC-6: sin seeds → equivalente a PageRank global (no lanza).
- [ ] AC-7: `vaults graph ppr` imprime top-N ordenado.
- [ ] AC-8: complejidad acotada (maxIterations * E) — no diverge con grafo cíclico.

## 4. Tests

`tests/ppr.test.ts` (vitest): unit — seed ranking, convergencia, ciclos, grafo
vacío, determinismo, integración con traverse.
