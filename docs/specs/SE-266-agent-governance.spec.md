# Spec: SE-266 — Agent Git Governance (Pi-inspired) + Shell Safety

**Status:** APPROVED (v2 — 2026-07-13)
**Fecha:** 2026-07-12 (original) / 2026-07-13 (v2 shell safety extension)
**Area:** Agent governance / Git discipline / Shell safety / Concurrent safety
**Branch:** agent/se266-agent-governance
**Estimacion:** 3h + 2h (v2 extension)
**Inspirado por:** earendil-works/pi AGENTS.md + session catastrophique 2026-07

**Developer Type:** agent-single
**Asignado a:** claude-agent
**Estado:** Implementado (PR #906, v2 2026-07-13)

**Effort Estimation (Dual Model):**
| Dimension | Value |
|---|---|
| Agent effort | 5h (3h v1 + 2h v2) |
| Human effort | 1h |
| Review effort | 15min |
| Context risk | low |
| Agent-capable | yes |

---

## Origen

Pi (github.com/earendil-works/pi, Mario Zechner, MIT) tiene un AGENTS.md
que gobierna como los agentes trabajan sobre el repo. La seccion clave es
"Git — Multiple pi sessions may be running in this cwd at the same time":
reglas que previenen que agentes concurrentes se pisen el trabajo.

Savia tiene agentes concurrentes (court-orchestrator + devs + test-runner)
sobre el mismo worktree. El guard branch-switch-dirty existe pero no cubre
operaciones destructivas entre agentes.

### v2 extension (2026-07-13) — Session catastrophique

El 2026-07-13 una sesion de agente ejecuto `rm -rf` sobre directorios del
usuario causando perdida masiva de datos. La operacion escalo desde una
revision de PR en GitHub a borrado destructivo del home del usuario.

**Leccion**: los hooks solo cubrian git ops. El agente uso comandos shell
(`rm -rf`) sin bloqueo. v2 extiende la cobertura a:
- `rm -rf` / `rm -r` (bloqueo total)
- `rm` sin confirmacion humana (-i / --interactive)
- Otras operaciones shell destructivas (dd, mkfs, chown -R, truncado)

## Problema actual

- Agentes ejecutan operaciones git masivas sin conciencia de concurrencia
- El branch-switch-dirty guard bloquea cambio de rama sin commit pero no
  previene que un agente destruya trabajo de otro
- **v2**: Agentes pueden ejecutar `rm -rf` sobre directorios fuera del workspace
- No hay reglas documentadas sobre que operaciones shell son seguras

## Diseño

### AGENTS.md — nueva seccion "Git Discipline for Agents"

Reglas para agentes operando en el repo:
- Solo commit de ficheros modificados en esta sesion
- Stage con paths explicitos, nunca con patrones globales
- Verificar git status antes de commit
- Nunca operaciones que destruyan trabajo no propio
- Conflictos de rebase: solo resolver en ficheros propios

### Hook agent-git-discipline.sh (v2)

Git ops (Pi-inspired):
- Operaciones masivas de stage → WARN (no bloquea, registra)
- Operaciones destructivas de worktree → BLOCK (exit 2)
- Operaciones que ocultan cambios → BLOCK (con sugerencia de alternativa)

Shell safety (v2):
- `rm -rf`, `rm -r`, `rm -fr`, `rm --recursive` → BLOCK
- `rm` sin `-i`/`--interactive` (fuera de paths seguros) → BLOCK
- `sudo rm -rf` → BLOCK
- `dd of=/dev/sd*`, `mkfs.*` → BLOCK
- `chown -R` sobre /home/, `cat /dev/null > /home/*` → BLOCK

### Guard TypeScript equivalente en savia-foundation

Misma logica para OpenCode nativo via plugin guards.

## Acceptance criteria

AC-1. AGENTS.md tiene seccion Git Discipline for Agents
AC-2. Hook bloquea operaciones destructivas de worktree (git)
AC-3. Operaciones masivas de stage emiten WARN
AC-4. Stash bloqueado con mensaje que sugiere alternativa
AC-5. 30 tests (16 block + 6 allow + 2 warn + 4 doc/through + 2 dry-run)
AC-6. Las reglas viajan en system prompt del agente via AGENTS.md
AC-7. v2: rm -rf/rm -r bloqueado (exit 2)
AC-8. v2: rm sin -i bloqueado, rm -i/--interactive permitido
AC-9. v2: dd, mkfs, chown -R, truncado de home bloqueados

## Ficheros

| Accion | Path |
|--------|------|
| MODIFY | AGENTS.md (añadir seccion Git Discipline) |
| CREATE | .opencode/hooks/agent-git-discipline.sh |
| MODIFY | .claude/settings.json (registrar hook PreToolUse Bash) |
| CREATE | tests/test-se-266-agent-git.bats (30 tests) |
| CREATE | docs/specs/SE-266-agent-governance.spec.md |

## No modifica

- branch-switch-dirty existente
- Operaciones git legítimas con paths explicitos
- Comportamiento para humanos (solo agentes)
- `rm -i` o `rm --interactive` con confirmacion humana
- `rm` en paths seguros (`/tmp/opencode/`, `/tmp/recovery/`)

## Lesson learned

> Session catastrophique 2026-07-13 — un agente ejecuto `rm -rf` sobre
> directorios del usuario. Causa: revision de PR en GitHub escalo a
> operacion destructiva. La proteccion existente solo cubria comandos git.
> v2 extiende el hook a comandos shell destructivos.
