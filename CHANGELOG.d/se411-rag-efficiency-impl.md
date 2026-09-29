---
version_bump: patch
section: Fixed
---

### Fixed

- SE-411 Savia RAG: la búsqueda en varias cúpulas ya no depende del orden (fusión por coseno; MRR en savia-docs + 3 cúpulas de 0,125 en el peor orden a 0,557) y no recarga índices en cada llamada (`domes:"*"` p95 2,0 s → 154 ms). Respuesta compacta de `vault_rag` (≤ 6 000 caracteres, 61 % de texto útil), modelo de embedding retenido 30 min y CLI `rag search` en savia-docs de 2,5 s a 0,93 s.
