---
id: SE-226
title: SantanderAI stateless-session loop para overnight-sprint
status: PARTIALLY_IMPLEMENTED
priority: P1
effort: M (5h)
origin: Research 2026-06-24 — github.com/SantanderAI/ralph (stateless agent loop, stdlib-only)
author: Savia
related: overnight-sprint skill, code-improvement-loop skill, autonomous-safety.md
proposed_at: "2026-06-24"
implemented_at: "2026-06-24"
era: 235
pr: agent/se226-stateless-loop-20260624
---

# SE-226 — Stateless-session loop para overnight-sprint

## Estado de implementacion

**PARTIALLY_IMPLEMENTED** — Infraestructura de scripts completa. SKILL.md pendiente de merge PR #853.

| Componente | Estado | Notas |
|---|---|---|
| scripts/overnight-sprint-state.sh | IMPLEMENTED | init/checkpoint/complete/fail/status/export + --self-test |
| scripts/overnight-sprint-loop.sh | IMPLEMENTED | Model escalation, abort gates, audit log |
| tests/test-overnight-sprint-state.bats | IMPLEMENTED | 15 tests, 15/15 pass |
| .opencode/skills/overnight-sprint/SKILL.md | PENDING | En cola PR #853 — NO modificar |

## Problema

El skill overnight-sprint ejecuta un agente de larga duracion en una sola sesion continua. Cuando el contexto supera el 80%, ejecuta /compact (lossy) y continua. Cuando Claude agota tokens, el sprint muere sin recuperacion.

Evidencia directa: sesion ses_10e77612 de 2026-06-23 se corto abruptamente en checkout de rama nueva.

## Tesis

Patron **stateless-session loop** de SantanderAI/ralph: cada iteracion lanza un agente fresco con estado en ficheros del workspace. Cada tarea es atomica. Si el agente muere, la siguiente iteracion retoma desde el ultimo estado guardado.

## Scripts implementados

### scripts/overnight-sprint-state.sh

Gestion de state.json con escritura atomica (tmp + mv).

Comandos: init, checkpoint, complete, fail, status, export, --self-test

- State en output/agent-runs/<sprint-id>/state.json
- Write atomico: mktemp + mv -f
- AGENT_RUNS_DIR env var override para testing aislado
- OVERNIGHT_SPRINT_ID env var para resolver sprint activo
- init es idempotente: si state ya existe, no sobreescribe (recovery automatico)
- complete resetea consecutive_failures; fail lo incrementa

### scripts/overnight-sprint-loop.sh

Orquestador stateless. Gestiona estado y delega ejecucion al caller hook.

Uso: overnight-sprint-loop.sh --sprint-id <id> --tasks <json-file> [--max-tasks 10] [--dry-run]

- Model escalation: fast -> mid -> heavy solo en TOKEN_EXHAUSTION (exit 2)
- OOM/TIMEOUT/INFRA (exit 3 o 124): no escala, registra fallo, continua
- Abort si consecutive_failures >= AGENT_MAX_CONSECUTIVE_FAILURES (default: 3)
- Time-box: AGENT_TASK_TIMEOUT_MINUTES (default: 15)
- Audit log: output/agent-runs/<sprint-id>-audit.log
- run_agent_task() es override-able por el caller
- --dry-run: simula ejecucion sin lanzar agentes

## Tests

tests/test-overnight-sprint-state.bats — 15 tests, 15/15 pasan.

## Slices

### Slice 1 — State persistence (DONE)

- scripts/overnight-sprint-state.sh
- tests/test-overnight-sprint-state.bats
- scripts/overnight-sprint-loop.sh

### Slice 2 — SKILL.md integration (PENDING — PR #853)

Refactorizar overnight-sprint SKILL.md para usar overnight-sprint-loop.sh

### Slice 3 — code-improvement-loop [diferido]

Mismo patron de loop stateless, compartiendo overnight-sprint-state.sh como libreria.

## Risks

| Riesgo | Probabilidad | Mitigacion |
|---|---|---|
| Subagente fresco sin contexto previo | Alta | state.json incluye resumen de tareas anteriores |
| Demasiados subagentes en paralelo | Media | Semaforo: max_parallel=1 por defecto |
| state.json corruption en crash | Baja | Write atomico via tmp + mv |
