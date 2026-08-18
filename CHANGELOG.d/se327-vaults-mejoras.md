---
version_bump: minor
section: Added
---

### Added

- SE-327..SE-331 — Mejoras de conocimiento en SaviaVaults (RAG/grafo), basadas
  en el artículo de referencia "RAG vs. Agentic Graph" (LinkedIn) + investigación
  de Microsoft GraphRAG (local/global/DRIFT), LightRAG y RAGAS:
  - **SE-327 PPR** (`projects/savia-vaults/src/knowledge/ppr.ts`): Personalized
    PageRank determinista (power method, sin deps/LLM). `traverse` ordena por
    PPR con la semilla como startId; `vaults graph --action ppr` expone ranking.
  - **SE-328 Dual-mode** (`src/knowledge/communities.ts`): detección de
    comunidades (componentes conexos) + resumen global con tipos/relaciones
    dominantes y hubs top-PPR. `vaults query --mode global|hybrid` (GraphRAG
    local vs global search, LightRAG hybrid).
  - **SE-329 Entity resolution** (`src/knowledge/entity-resolution.ts`):
    canonicalización de IDs (NFKD, acentos, case, separadores) + sinónimos;
    resuelve aliases en query, reporta colisiones (naming consistente).
  - **SE-330 Context enrichment** (`src/search/enrichment.ts`): fusión BM25+grafo
    (`score = bm25 * (1 + α·graphScore)`), `vaults search --enrich`, best-effort
    (GraphRAG local dataflow).
  - **SE-331 Retrieval eval** (`src/search/eval.ts`): precision@k / recall@k
    deterministas (RAGAS-like); `vaults eval-search --modes bm25,enriched`.
   - `seed-example-context.sh`: puebla un vault local desde las specs del proyecto.
   - Test con un vault local: PPR, global, hybrid, enrich
    y eval-search validados. 56 tests nuevos (338 total).

### Notes

- Todo determinista, sin LLM ni embeddings (alineado con SE-288). Los cambios
  son aditivos y backward-compatible (`--enrich` y `--mode` default off/local).
