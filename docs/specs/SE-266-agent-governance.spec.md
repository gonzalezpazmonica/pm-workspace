# Spec: SE-266 — Agent Git Governance (Pi-inspired)

**Status:** PROPOSED
**Fecha:** 2026-07-12
**Area:** Agent governance / Git discipline / Concurrent safety
**Branch:** agent/se266-agent-governance
**Estimacion:** 3h
**Inspirado por:** earendil-works/pi AGENTS.md — concurrent agent safety rules

**Developer Type:** agent-single
**Asignado a:** claude-agent
**Estado:** Pendiente

**Effort Estimation (Dual Model):**
| Dimension | Value |
|---|---|
| Agent effort | 3h |
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

## Problema actual

- Agentes ejecutan operaciones git masivas sin conciencia de concurrencia
- El branch-switch-dirty guard bloquea cambio de rama sin commit pero no
  previene que un agente destruya trabajo de otro
- No hay reglas documentadas sobre que operaciones git son seguras

## Diseño

### AGENTS.md — nueva seccion "Git Discipline for Agents"

Reglas para agentes operando en el repo:
- Solo commit de ficheros modificados en esta sesion
- Stage con paths explicitos, nunca con patrones globales
- Verificar git status antes de commit
- Nunca operaciones que destruyan trabajo no propio
- Conflictos de rebase: solo resolver en ficheros propios

### Hook agent-git-discipline.sh

Deteccion pre-ejecucion de patrones peligrosos:
- Operaciones masivas de stage → WARN (no bloquea, registra)
- Operaciones destructivas de worktree → BLOCK (exit 1)
- Operaciones que ocultan cambios → BLOCK (con sugerencia de alternativa)

### Guard TypeScript equivalente en savia-foundation

Misma logica para OpenCode nativo via plugin guards.

## Acceptance criteria

AC-1. AGENTS.md tiene seccion Git Discipline for Agents
AC-2. Hook bloquea operaciones destructivas de worktree
AC-3. Operaciones masivas de stage emiten WARN
AC-4. Stash bloqueado con mensaje que sugiere alternativa
AC-5. 3 tests BATS (warn, block, block)
AC-6. Las reglas viajan en system prompt del agente via AGENTS.md

## Ficheros

| Accion | Path |
|--------|------|
| MODIFY | AGENTS.md (añadir seccion Git Discipline) |
| CREATE | .opencode/hooks/agent-git-discipline.sh |
| CREATE | tests/test-se-266-agent-git.bats |

## No modifica

- branch-switch-dirty existente
- Operaciones git legítimas con paths explicitos
- Comportamiento para humanos (solo agentes)
