---
version_bump: patch
section: Fixed
---

### Fixed

- SE-412: `vault_search` deja de indexar ficheros que no son markdown y de tomar referencias `#648` como tags (MRR en savia-docs 0,251 → 0,275); la CLI `search` cachea su índice (1,37 s → ~0,5 s); una cúpula que vence el timeout del fan-out de Savia RAG ya no carga su índice después (causa de un test intermitente).
