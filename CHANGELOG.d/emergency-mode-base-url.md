---
version_bump: patch
section: Fixed
---

### Fixed

- emergency-mode: el switchover documentado (ANTHROPIC_BASE_URL=http://localhost:8080/v1) hacía que Claude Code pidiera /v1/v1/messages; la base va sin /v1. localai-readiness-check: modelo por id exacto, JSON siempre válido, argumentos sin valor o seguidos de otra bandera → exit 2; imprime el switchover completo (ANTHROPIC_BASE_URL, ANTHROPIC_MODEL, ANTHROPIC_SMALL_FAST_MODEL) solo si el modelo pedido está cargado (si no, FAIL con los ids disponibles); barra final eliminada también en LOCALAI_URL; RAM y disco no medibles (macOS) son WARN y los umbrales se inyectan por entorno.

