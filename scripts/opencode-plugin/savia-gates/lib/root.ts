// Raíz del proyecto para savia-gates: donde vive el registro `.claude/settings.json`.
//
// OpenCode pasa `directory` (donde se abrió la sesión, que puede ser un subdirectorio) y
// `worktree` (la raíz git; en un worktree enlazado, la de ese worktree). Con `directory` como
// raíz, una sesión abierta en `docs/` buscaba `docs/.claude/settings.json`, no lo encontraba y
// bloqueaba todos los prompts con INVALID_HOOK_CONFIGURATION. Sin git, `worktree` es "/" y se usa
// `directory`: si ahí no hay registro, todo sigue bloqueado (fail-closed, SE-394 AC03).
// No se busca hacia arriba: fuera de un repo encontraría `~/.claude/settings.json`, que no es el
// registro de ningún proyecto.
export function resolveProjectRoot(directory?: string | null, worktree?: string | null): string {
  if (worktree && worktree !== "/") return worktree
  if (directory) return directory
  return process.env.PROJECT_ROOT || `${process.env.HOME}/claude`
}
