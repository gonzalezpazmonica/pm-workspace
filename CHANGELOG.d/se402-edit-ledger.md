---
version_bump: minor
section: Added
---
- SE-402 registro de ediciones atribuidas: hook PostToolUse `Edit|Write|NotebookEdit` (async, p95 21 ms) guarda ruta y sha256 (nunca contenido) en `~/.savia/edits/<sesión>.jsonl`; `scripts/edit-ledger.sh verify` lista los cambios de la rama que ninguna escritura registrada explica (tests o scripts que mutan el repo). Gate G19 advisory en `pr-plan`. Binding OpenCode en `savia-foundation.ts`. Exclusiones de derivados en `config/edit-ledger-exclusions.txt`.
