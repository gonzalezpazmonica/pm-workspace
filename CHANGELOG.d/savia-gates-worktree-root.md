---
version_bump: patch
section: Fixed
---
- savia-gates bloqueaba todos los prompts con `INVALID_HOOK_CONFIGURATION` cuando OpenCode se abría en un subdirectorio del repo (p. ej. `docs/`): tomaba como raíz el `directory` de la sesión y buscaba allí `.claude/settings.json`. La raíz es ahora el `worktree` de OpenCode (la raíz git, también en un worktree enlazado); sin git (`worktree` = `/`) se usa el directorio y, si no tiene registro, todo sigue bloqueado (fail-closed, SE-394 AC03). Las rutas relativas de las herramientas se siguen resolviendo contra el directorio de la sesión. 4 tests nuevos en `__tests__/root.test.ts`.
