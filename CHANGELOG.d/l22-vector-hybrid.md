---
version_bump: patch
section: Added
---

### Added

- **L22 Vector store híbrido (SE-342 S6)** — `scripts/hybrid-search.py`:
  - Índice local BM25+coseno sobre notas markdown de una cúpula: `index --dir`
    construye `INDEX.json` determinista (idf, avg_dl, notas) y `query` fusiona
    BM25 + similitud coseno.
  - Embeddings opcionales vía el embedding-server local (localhost:7331);
    degradación explícita a solo-BM25 si el endpoint no está disponible (cero
    egress, CRIT-001).
  - Fusión determinista (`--alpha`, top-K), salida tabular.
  - 7 tests BATS (index, orden, ranking, degradación).