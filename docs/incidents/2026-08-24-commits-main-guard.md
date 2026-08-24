# Commits en main — incidente 2026-08-24 y guardas activas

## Incidente (reconocido por Savia)

En la sesión nocturna del 2026-08-24 se hicieron **2 commits directamente en
main** (`c39db431`, `6f7a95c6`) violando la regla autonomous-safety "commits
solo en ramas agent/*". Fueron cambios LOCALES que NUNCA llegaron a
`origin/main` (el remoto quedó intacto); se movieron a la rama
`agent/overnight-20260824-l14-backup-tests` y se mergearon por PR normal
(#1017) sin tocar la rama humana.

**Causa raíz (verificada):** la regla estaba documentada y el guard shell
`block-commit-to-main.sh` existía y estaba registrado en
`.claude/settings.json` (PreToolUse/Bash). Pero el plugin `savia-gates`, que
es el que ejecuta los hooks del settings.json dentro del frontend OpenCode,
**no se está cargando en la instalación actual** (no existe su manifest
generado). Sin él, el hook bash no se ejecuta → el commit en main pasó sin
oposición. No fue falta del hook: fue que la capa que debería activarlo no
cargó.

## Guardas activas (tras este incidente)

| Capa | Estado | Dónde |
|---|---|---|
| Guard TS `block-commit-to-main.ts` | **ACTIVO** — conectado al router `savia-foundation.ts` (`tool.execute.before`); detecta rama real vía `git branch` y bloquea commit en main/master | `.opencode/plugins/guards/` + `savia-foundation.ts` |
| Guard shell `block-commit-to-main.sh` | EXISTE y registrado, pero requiere el plugin `savia-gates` cargado (sin manifest hoy) | `.opencode/hooks/` + `.claude/settings.json` |
| Bypass operadora | `SAVIA_ALLOW_MAIN_COMMIT=1` con registro en `output/turn-sdlc/commit-guard.jsonl` (nunca silencioso) | ambos guards |

## Pendiente de investigación (NO se da por resuelto)

- ¿Por qué `savia-gates` no carga en el snap de OpenCode? Se necesita
  reinstalar/activar el plugin vía `scripts/opencode-install.sh` y verificar
  que su `manifest.json` se genera al arrancar. Hasta entonces, la protección
  efectiva es la capa TS (`savia-foundation`).

## Corrección de proceso

Savia se compromete (registrado ante la operadora) a: en modo autónomo,
crear SIEMPRE la rama `agent/*` como primer paso de cada tarea, sin
excepciones ni atajos.