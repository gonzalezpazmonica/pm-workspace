# Spec: SE-330 — Context enrichment: fusión BM25 + grafo

**Task ID:**        SE-330
**PBI padre:**      SE-330 — Context enrichment en search
**Sprint:**        2026-08
**Fecha creacion:** 2026-08-14
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     typescript-developer
**Estado:**         IMPLEMENTED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|---|---|
| Agent effort | 4 h |
| Human effort | 2 h |
| Review effort | 15 min |
| Context risk | medium |
| Agent-capable | yes |

---

## 1. Contexto y Objetivo

La búsqueda de SaviaVaults es BM25 puro (MiniSearch, search/index.ts): devuelve
notas por similitud léxica. GraphRAG (local search dataflow) fusiona texto con
estructura: los hits léxicos se expanden con entidades y relaciones vecinas del
grafo antes de devolver contexto, mejorando la recuperación sin LLM en el hot
path.

Objetivo: **context enrichment** determinista — dado un resultado de búsqueda,
enriquecer con:
- entidades del grafo mencionadas en la nota (por frontmatter entity y wikilinks),
- vecinos de primer grado de esas entidades (relaciones),
- score combinado final = BM25 * (1 + α * graphRelevance).

## 2. Contrato Tecnico

### 2.1 Enrichment

```typescript
// src/search/enrichment.ts
interface EnrichedResult {
  path: string;
  title: string;
  score: number;             // BM25 combinado con graphRelevance
  bm25Score: number;
  graphScore: number;        // 0..1 — PPR-based relevance de sus entidades
  entities: string[];        // entidades del grafo referenciadas por la nota
  neighbors: { from: string; to: string; type: string }[];  // primer grado
}

class ContextEnricher {
  enrich(
    results: SearchResult[],
    graph: GraphSnapshot,
    ppr: PPRRanker,
    options?: { alpha?: number }   // default 0.3
  ): EnrichedResult[];
}
```

Semántica:
- Para cada nota, extraer entity ids del frontmatter + targets de wikilinks.
- `graphScore` = max PPR score (seeds = entidades de la nota, o global si no
  tiene entidades) del nodo o sus vecinos.
- `score = bm25Score * (1 + alpha * graphScore)`; orden estable por score final.
- Sin entidades en la nota → graphScore 0 (queda BM25 puro).

### 2.2 Integración

`SearchEngine.search(query)` acepta `{ enrich?: boolean }`. Con enrich, usa
ContextEnricher y devuelve `EnrichedResult[]`. MCP `vault_search` y CLI
`vaults search` exponen `--enrich` (default off; no rompe contrato actual).

### 2.3 Telemetría

`search.enriched` (schema savia.event/1.0): `{query, results, enriched,
avg_graph_score}` — para comparar calidad antes/después.

## 3. Criterios de aceptacion

- [ ] AC-1: enrich off → comportamiento actual intacto (BM25 puro).
- [ ] AC-2: enrich on con nota que referencia entidad → graphScore > 0 y score final > bm25.
- [ ] AC-3: nota sin entidades → graphScore 0, score == bm25.
- [ ] AC-4: neighbors incluye solo relaciones de primer grado.
- [ ] AC-5: orden final estable y determinista.
- [ ] AC-6: vault vacío o sin resultados → array vacío, no lanza.
- [ ] AC-7: MCP/CLI exponen `--enrich` sin romper el contrato existente.
- [ ] AC-8: telemetría `search.enriched` emitida cuando enrich activo.

## 4. Tests

`tests/context-enrichment.test.ts` (vitest): enrichment, alpha, sin entidades,
determinismo, integración SearchEngine, telemetría.
