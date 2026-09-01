---
version_bump: patch
section: Added
---

### Added

- SE-354 Read-Only Permission Mode: `permission-mode-gate.sh` (PreToolUse) deniega estructuralmente las tools de mutación (Write/Edit/MultiEdit y comandos Bash de mutación como git push/commit/merge, rm, mv) cuando la sesión corre con `SAVIA_PERMISSION_MODE=read-only`. Denegación en código (exit 2), no promesa al modelo; modo `full` sin cambios. 16 bats tests.
