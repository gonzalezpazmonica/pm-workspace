---
version_bump: patch
section: Fixed
---

### Fixed

- savia-gates: con SAVIA_GATES_PIN=1 (Space en modo mediado) fija por hash el registro y los scripts de guard al cargar cada directorio y bloquea (GUARDS_MODIFIED) si cambian; las ediciones de guards se bloquean (GUARD_PROTECTED). Los hooks se ejecutan bajo bwrap desde una copia de confianza de .claude/hooks y scripts/, así que editar scripts/savia-env.sh u otro helper no anula los guards, y la primera violación se queda hasta reiniciar el motor. La copia se verifica antes y después de los hooks, de modo que una escritura en ella durante el pipeline bloquea esa misma decisión. Antes, un guard editado en el worktree del agente valía en la siguiente llamada (T1).

