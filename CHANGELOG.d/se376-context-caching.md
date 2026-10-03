---
version_bump: patch
section: Fixed
---

### Fixed

- cache-metrics.sh (skill context-caching): --usage-json ya no se interpola como código Python (inyección), rechaza recuentos inválidos o en formato es_ES en vez de guardarlos mal, y report/--validate/ingest-opencode no rompen con filas corruptas o DB ajena

