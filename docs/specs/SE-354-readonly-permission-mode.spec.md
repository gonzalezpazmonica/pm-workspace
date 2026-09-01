# SE-354 — Read-Only Permission Mode: sesión de consulta sin tools de mutación

**Status:** APPROVED (2026-08-31, operadora grant merge sesión nocturna)
**Fecha:** 2026-08-31
**Área:** Seguridad / Policy-as-code
**Fuente de inspiración:** OpenClaw 2.0 (permission modes: read-only omite edit/write/apply_patch; policy as code)
**Criterio humano aplicable:** CRIT-001

---

## Objetivo

Añadir un **modo de permiso read-only** que **omite** las tools de mutación
(`Edit`, `Write`, `apply_patch`, `Bash` con flags destructivos) a nivel de
sesión — denegación **estructural**, no promesa al modelo. Cuando el modo está
activo, esas tools **no existen** para esa sesión, y el denial se enuncia en
código (hook), no en el system prompt.

## Contexto

OpenClaw implementa "policy as code": una sesión `read-only` **no tiene** las
tools de mutación registradas, el exec resuelve a deny en el call boundary, y
`full` requiere `operator.admin`. Savia tiene gates por regex de comando
(SE-266: bloquea `git reset --hard`, `rm -rf`, etc.) — correctos pero **reactivos
por comando**, no modales por sesión. El gap: no existe "sesión de solo lectura"
donde la superficie de mutación simplemente no exista. Caso de uso inmediato:
sesiones de auditoría, review, o consulta (`/sprint-status`, research) donde
cualquier write es out-of-scope.

**Rechazo explícito (CRIT-001):** modo 100% local, implementado como hook +
settings por-sesión. Sin ningún servicio externo.

## Diseño

### 1. Modo por sesión

Variable `SAVIA_PERMISSION_MODE=read-only|full` (default `full`). Cuando es
`read-only`:

- `.claude/settings.json`: matcher de PreToolUse que **deniega** `Write`, `Edit`,
  `MultiEdit`, `Bash` con comandos de mutación, y llamadas a `git push/commit/merge`.
- Whitelist de excepción read-safe en `Bash`: `git status/log/diff/fetch`,
  `ls/cat/grep`, scripts de lectura (`.sh` de consulta).

### 2. Hook `permission-mode-gate.sh`

`scripts/permission-mode-gate.sh`:
- Lee `SAVIA_PERMISSION_MODE` de la sesión
- Si `read-only` y tool de mutación → **BLOQUEADO** (exit 2), mensaje con razón
- Si `read-only` y Bash no en whitelist read-safe → BLOQUEADO
- Log en `data/permission-denials.jsonl` (metadata-only, sin args/PII)

### 3. Modos de ejecución

- `full` — comportamiento actual (sin cambios)
- `read-only` — gate activo
- Integración: comandos de consulta (`/sprint-status`, `/weekly-report`) se
  pueden lanzar con `--read-only` explícito.

## Criterios de aceptación

- **AC-0** Modo `read-only`: `Write` y `Edit` denegadas por hook (exit 2)
- **AC-1** Modo `read-only`: `Bash` con `git push`/`rm` denegado
- **AC-2** Modo `read-only`: `Bash` con `git status`/`cat` permitido (exit 0)
- **AC-3** Modo `full`: ningún cambio de comportamiento (regresión cero en suite existente)
- **AC-4** Denials loggeados metadata-only (sin comandos completos con secrets)
- **AC-5** `--read-only` lanzable por comando con documentación en pm-workflow.md

## OpenCode Implementation Plan

### Bindings touched
- `scripts/permission-mode-gate.sh` (nuevo)
- `.claude/settings.json` (registro PreToolUse), `.opencode/hooks/` (symlink compartido)
- `docs/rules/domain/pm-workflow.md`, `docs/rules/domain/critical-rules-extended.md`

### Verification protocol
```bash
bats tests/bats/test-permission-mode.bats
SAVIA_PERMISSION_MODE=read-only bash scripts/permission-mode-gate.sh  # negativo
```

### Portability classification
- Hooks compartidos Claude/OpenCode; bash portable

## Trabajo futuro (fuera de scope)
- Rol ceilings multi-usuario (OpenClaw roles) — spec independiente
- Sandboxing real de ejecución — out of scope (necesita decisión de infra)
## Validación (ejecutada en esta sesión)

- `tests/bats/test-se354-permission-mode.bats`: 16 bats verdes
  - read-only: Write/Edit/MultiEdit bloqueadas (exit 2)
  - read-only: git status/diff, ls, cat permitidos (exit 0)
  - read-only: git push/commit/merge, mv bloqueados (exit 2)
  - full: Write y git push permitidos (exit 0)
  - fail-soft: JSON inválido / modo vacío / input vacío → exit 0

## Referencias

- OpenClaw: `docs/start/why-openclaw.md` (Policy as code, permission modes)
- Savia: SE-266 (agent-git-discipline), `docs/rules/domain/autonomous-safety.md`, CRIT-001
