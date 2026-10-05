---
version_bump: patch
section: Fixed
---

### Fixed

- savia-gates: en modo mediado (SAVIA_GATES_PIN=1) un workspace con `.claude/settings.json` pero sin `.claude/hooks` ya no falla con ENOENT al preparar la copia de confianza ni bloquea todos los prompts.
- savia-gates: el plugin ya no reescribe `manifest.json` en su directorio al cargarse; el manifiesto es determinista (sin `generated_at`) y lo genera `opencode-install.sh`. Savia Space deja de marcar ENGINE_INTEGRITY DEGRADED por un `pluginSetHash` que cambiaba en cada arranque.
- savia-gates: las copias `savia-gates-trusted-<pid>-*` de motores muertos con SIGKILL se barren al preparar una copia nueva (solo directorios reales del mismo usuario cuyo PID ya no existe).
