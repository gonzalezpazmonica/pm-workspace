# SE-349 — Agent Runs Operations Ledger (ARO): estado derivado + board operativo de runs autónomos

**Status:** APPROVED (implementation-ready)
**Fecha:** 2026-08-29
**Área:** Agent observability / Autonomous operations
**Fuente de inspiración:** https://github.com/Untrivial-ai/agent-orchestrator (AO)
**Criterio humano aplicable:** CRIT-001 (datos en infraestructura propia, N3+ jamás a cloud)

---

## Objetivo

Crear un **ledger operativo de runs autónomos** con dos propiedades heredadas de
Agent Orchestrator: (1) **el estado de display nunca se almacena, se deriva en
lectura** de hechos durables; y (2) **guardrail de terminación conservadora** —
un run que aún posee un PR vivo no es terminable ("failed probes are NOT proof
of death"). Entrega un board operativo (Working / Needs you / In review / Ready
to merge / Done) computado al vuelo, consultable por CLI y por agentes.

## Contexto

Tras analizar AO (`docs/architecture.md`, 1050 líneas) y comparar contra
pm-workspace, el gap real no es el daemon Go/Electron (no portable a un
workspace de prompts), sino tres principios arquitectónicos portables que Savia
todavía no aplica de forma sistemática a sus runs autónomos:

| Principio AO | Estado en Savia | Gap |
|---|---|---|
| 1. "Never store display status — derive at read time" | `savia-flow-board.sh` lee `status:` almacenado en cada PBI; `agent-actuals.jsonl` guarda `run_status` en el registro | No existe estado derivado para runs; el estado vive en el dato |
| 2. "Failed probes are NOT proof of death" + guardrails de terminación | `autonomous-safety.md` aborta tras 3 fallos consecutivos (es retry, correcto) pero un run se da por "end:" en el audit aunque su PR siga abierto | No hay guardrail que impida terminar un run que aún posee PR vivo |
| 3. Feedback loop (SCM observer → nudge) | `fix-assigner` es Court-interno; nada enruta `changes_requested`/`ci_failed` de vuelta al run que posee el PR | Falta la capa de hechos de PR (number/state/ci/review/mergeable) que un observador ADO futuro consumirá |

**Rechazo explícito (CRIT-001):** AO envía telemetría anónima a PostHog
incluyendo el segmento owner de GitHub. SE-349 **NO** replica telemetría cloud.
Todo el ledger es local (`data/`), sin red, sin proveedor. El lesson de AO que
se adopta es la **arquitectura local** (SQLite/JSONL en `~/.ao`, daemon
127.0.0.1), no su telemetría.

## Hechos durables (schema v1, JSONL append/upsert)

Ledger: `data/agent-runs-ledger.jsonl` (ya gitignored vía `/data/*`).
Cada línea es un registro completo; `run_id` identifica el run. Un run nace con
`start`, se actualiza con `state`/`pr`, y muere con `finish`.

| Campo | Tipo | Valores | Nota |
|---|---|---|---|
| `schema_version` | string | `"1"` | Discriminador |
| `run_id` | string | UUID | Clave |
| `mode` | string | `overnight\|improve\|research\|agent-task\|sdd` | Cómo se lanzó |
| `agent` | string | nombre del agente | |
| `project` | string | proyecto (opcional) | |
| `branch` | string | rama `agent/*` (opcional) | |
| `task` | string | descripción del run | |
| `url` | string | PR URL (opcional) | |
| `activity_state` | string | `spawning\|active\|waiting_input\|blocked\|exited` | Solo este hecho de actividad |
| `is_terminated` | boolean | | Solo este hecho de terminación |
| `started_at` | ISO-8601 | | |
| `updated_at` | ISO-8601 | | |
| `ended_at` | ISO-8601 \| null | | |
| `pr` | object \| null | `{number, state, ci, review, mergeable, url}` | Hechos de PR (ver abajo) |

### Hechos de PR (`pr`)

| Subcampo | Valores |
|---|---|
| `number` | int |
| `state` | `open\|draft\|merged\|closed` |
| `ci` | `unknown\|pending\|passing\|failing` |
| `review` | `none\|requested\|changes_requested\|approved` |
| `mergeable` | `unknown\|true\|false` |

## Estado derivado (NUNCA se almacena)

Función pura evaluada en cada lectura, precedencia de mayor a menor (espejo de
`docs/architecture.md#status-derivation` de AO):

```
is_terminated = true  → pr.state == merged  ? merged
                     →                      : terminated
activity_state in (waiting_input, blocked) → needs_input
tiene pr →
    ci == failing            → ci_failed
    state == draft           → draft
    review == changes_requested → changes_requested
    mergeable == false       → merge_conflict
    review == approved       → approved
    review == requested      → review_pending
    (open)                   → pr_open
activity_state == active     → working
cualquier otro caso          → idle
```

### Mapeo a columnas del board

| Columna | Estados derivados |
|---|---|
| WORKING | `working` |
| NEEDS YOU | `needs_input`, `ci_failed`, `changes_requested`, `merge_conflict`, `blocked` |
| IN REVIEW | `draft`, `review_pending`, `pr_open` |
| READY TO MERGE | `approved` |
| DONE | `merged` |
| TERMINATED | `terminated` |
| (footer) | `idle` (sin actividad; no ocupa columna) |

## Guardrail de terminación (AO load-bearing rule #2)

`finish <run_id>` **se niega** si el run posee un PR vivo: `pr` existe y
`pr.state` es `open` o `draft` y no `merged`. Razonamiento: un run cuyo PR sigue
vivo (CI pendiente, review, mergeable) no está muerto — "failed probes are NOT
proof of death". Bypass explícito con `--force` (solo tras merge/close del PR o
`pr <run_id> clear` para desposeerlo).

## CLI — `scripts/savia-runs.sh` (thin client, lógica en un solo script)

```
savia-runs.sh init                                        # asegura ledger existente
savia-runs.sh start <mode> <agent> <task> [--project P] [--branch B] [--url U]
                                                          # → imprime run_id
savia-runs.sh state  <run_id> <activity_state>            # spawning|active|waiting_input|blocked|exited
savia-runs.sh pr     <run_id> <number> [--state open|draft|merged|closed]
                           [--ci passing|failing|pending|unknown]
                           [--review none|requested|changes_requested|approved]
                           [--mergeable true|false|unknown] [--url U]
savia-runs.sh pr     <run_id> clear                       # desposee el PR (bypass limpio del guardrail)
savia-runs.sh finish <run_id> [--force]                   # guardrail de terminación
savia-runs.sh status [--json]                             # board derivado / JSON
savia-runs.sh list   [--mode M] [--json]                  # tabla de runs con estado derivado
savia-runs.sh show   <run_id>                             # hechos + estado derivado + traza de precedencia
savia-runs.sh reset                                       # vacía ledger (dev/test)
```

Reglas de implementación:

- Logging: `date -u +"%Y-%m-%dT%H:%M:%SZ"`; `run_id` vía `uuidgen` (fallback
  `date +%s%N`+PID, igual que `agent-run-logger.sh`).
- JSON engine: `python3` (disponible y usado en el workspace). Si falta,
  `start` degrada a JSON mínimo por heredoc; `state/pr/finish` avisan y salen 1.
- Todo registro es upsert por `run_id` (rewrite de la línea), mismo patrón que
  `agent-run-logger.sh`.

## Criterios de aceptación

- AC-1: `start` crea un registro v1 con `activity_state=spawning`, `is_terminated=false`, timestamps ISO y `pr=null`; imprime `run_id`.
- AC-2: `state` y `pr` actualizan el registro sin duplicar líneas (upsert por `run_id`).
- AC-3: `finish` sin PR marca `is_terminated=true` y `ended_at`; estado derivado = `terminated`.
- AC-4: `finish` con PR `open|draft` y sin `--force` falla (exit≠0) con mensaje de guardrail; con `--force` termina.
- AC-5: `pr <run_id> clear` desposee el PR y deja pasar `finish`.
- AC-6: `status` renderiza board con columnas WORKING/NEEDS YOU/IN REVIEW/READY TO MERGE/DONE/TERMINATED y contadores; derivación en lectura, sin campo de estado en el ledger.
- AC-7: `status --json` devuelve JSON con `as_of`, columnas y runs con `derived_status`.
- AC-8: `show` imprime hechos + estado derivado + traza de precedencia (por qué se derivó ese estado).
- AC-9: `list --json` respeta `--mode`; salida JSON parseable.
- AC-10: `reset` deja el ledger vacío (solo para dev/test).
- AC-11: Suite BATS `tests/test-se-349-agent-runs-ledger.bats` ≥ 15 tests (validación manual local; bats en CI).
- AC-12: Ninguna salida/registro contiene telemetría a proveedor externo; cero red (CRIT-001).

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| spec | `docs/specs/SE-349-agent-runs-ledger.spec.md` | lectura directa |
| script | `scripts/savia-runs.sh` (bash puro) | invocación bash directa |
| tests | `tests/test-se-349-agent-runs-ledger.bats` | bats runner (CI) |
| skill | `.opencode/skills/agent-runs-board/SKILL.md` | skill registry (SKILLS.md auto) |
| docs | `SKILLS.md`, `AGENTS.md` (auto-regenerados) | lectura directa |

### Verification protocol

- [x] Funciona en runtime OpenCode (script bash puro, sin bindings de frontend)
- [x] Smoke test local de cada subcomando (ver sección "Validación" de la spec)
- [ ] Tests bats ejecutados en CI (bats no instalado localmente; validación manual en este sprint)

### Portability classification

- [x] **PURE_BASH** — lógica en bash/python3 heredoc, cero bindings de frontend;
      runs idéntico en Claude Code y OpenCode.

## Validación (ejecutada en esta sesión)

```
R1=$(savia-runs.sh start overnight dev-orchestrator "smoke test")
savia-runs.sh state "$R1" active
savia-runs.sh pr "$R1" 999 --state open --ci failing
savia-runs.sh status          # board → columna NEEDS YOU (ci_failed)
savia-runs.sh finish "$R1"    # exit 1, guardrail
savia-runs.sh pr "$R1" clear && savia-runs.sh finish "$R1"  # OK → terminated
savia-runs.sh reset
```

## Trabajo futuro (fuera de scope de SE-349)

- **ADO Nudge Observer**: poll de PRs en Azure DevOps de ramas `agent/*`,
  escribe hechos `pr` en el ledger y enruta feedback (`changes_requested`,
  `ci_failed`, `merge_conflict`) al run que lo posee — espejo del SCM
  observer → nudge engine de AO. SE-349 deja el contrato de hechos listo.
- **Outbox durable**: mensajes durante la ventana sin controlador (AO handoff).
- **Event sourcing estricto**: cambiar `_upsert_record` por append-only
  `change_log` + poller (AO CDC). Requiere migrar `agent-actuals.jsonl`.

## Referencias

- AO `docs/architecture.md` — status derivation, guardrails, CDC (local: `/tmp` no; fuente: https://github.com/Untrivial-ai/agent-orchestrator/blob/main/docs/architecture.md)
- `docs/rules/domain/autonomous-safety.md` — ramas `agent/*`, PR Draft, audit logs
- `docs/specs/SE-148-agent-run-summary.spec.md` — patrón JSONL upsert de referencia
- `scripts/session-status.sh` — patrón python3 heredoc agregador
- CRIT-001 (criterio operadora) — datos N3+ jamás a proveedor cloud
