---
version_bump: patch
section: Fixed
---

### Fixed

- understand-anything calibrada (SE-376): ua-bridge ya no ejecuta knowledge-graph.py con bash ni da falso éxito sin opencode, diff --count incluye cambios staged y diff sale con 0; knowledge-graph.py tolera líneas JSONL no-objeto, mapea bug/pattern a memory_type, aplica --memory-type, valida --limit/--depth, trata % y _ como literales, filtra impact/status por --project y no borra provenance explícita.

