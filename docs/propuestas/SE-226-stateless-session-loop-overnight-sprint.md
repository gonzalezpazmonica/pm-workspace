---
id: SE-226
title: SantanderAI stateless-session loop para overnight-sprint
status: PROPOSED
priority: P1
effort: M (5h)
origin: Research 2026-06-24 — github.com/SantanderAI/ralph (stateless agent loop, stdlib-only)
author: Savia
related: overnight-sprint skill, code-improvement-loop skill, autonomous-safety.md
proposed_at: "2026-06-24"
era: 235
---

# SE-226 — Stateless-session loop para overnight-sprint

## Problema

El skill `overnight-sprint` ejecuta un agente de larga duración en una sola sesión continua. Cuando el contexto supera el 80%, el skill ejecuta `/compact` (lossy) y continúa. Cuando Claude agota tokens por límite de la API o por un error de infra, el sprint muere: no hay mecanismo de recuperación, el trabajo parcial se pierde, y la sesión no es reanudable.

Evidencia directa: la sesión `ses_10e77612` de 2026-06-23 se cortó abruptamente en el checkout de una nueva rama. No hubo graceful shutdown, no hubo registro del estado parcial.

Cost of inaction: a medida que se añaden más agentes autónomos (code-improvement-loop, tech-research-agent), el modelo de "sesión larga continua" se vuelve cada vez más frágil. Un sprint nocturno de 8h con 15 tareas puede perder todo por un error en la tarea 12.

## Tesis

Adoptar el patrón **stateless-session loop** de SantanderAI/ralph: cada iteración del sprint lanza un **agente fresco** con estado persisitido en ficheros del workspace. Cada tarea es atómica. Si el agente muere, la siguiente iteración del loop retoma desde el último estado guardado.

Bonus: rotación de modelos automática si se detecta token exhaustion (low→mid→heavy→abort).

## Diseño

### Arquitectura actual vs propuesta

```
ACTUAL:
  overnight-sprint → agente sesión larga → /compact × N → muerte por tokens
                                                                   ↑
                                                              trabajo perdido

PROPUESTO:
  overnight-sprint-loop.sh → [
    para cada tarea:
      1. escribir state en state.json
      2. lanzar agente fresco (claude --no-resume o subagent)
      3. agente lee state.json, ejecuta tarea, escribe resultado
      4. si ok: marcar completada en state.json, continuar
      5. si token exhaustion: escalar modelo, reintentar
      6. si crash: registrar en audit.log, continuar con siguiente
  ] → PR draft con todas las tareas completadas
```

### Formato state.json

```json
{
  "sprint_id": "overnight-20260624-fix-linter",
  "tasks": [
    {"id": 1, "description": "Fix warning X", "status": "done", "pr": "850"},
    {"id": 2, "description": "Fix warning Y", "status": "in_progress", "model": "mid"},
    {"id": 3, "description": "Fix warning Z", "status": "pending"}
  ],
  "started_at": "2026-06-24T23:00:00Z",
  "last_checkpoint": "2026-06-24T23:45:12Z",
  "model_escalations": 1
}
```

### Model rotation (inspirado en ralph)

```bash
MODELS=("fast" "mid" "heavy")
for model in "${MODELS[@]}"; do
    result=$(run_agent_with_model "$task" "$model")
    if [[ "$result" == "TOKEN_EXHAUSTION" ]]; then continue; fi
    if [[ "$result" == "OOM|TIMEOUT|INFRA_ERROR" ]]; then break; fi  # no escalar
    break
done
```

### stdlib-only en lógica de loop

El loop `overnight-sprint-loop.sh` usa solo: bash, jq (o python3 stdlib), git. Sin dependencias externas en el orquestador. El agente interno sí puede usar todas las tools habituales.

## Slices

### Slice 1 — State persistence (S, 2h)

- `scripts/overnight-sprint-state.sh`: init/checkpoint/complete/fail state.json
- BATS: init, checkpoint tras tarea, recovery desde state existente, export final
- Integrar en `overnight-sprint` skill: pre-task checkpoint, post-task commit

### Slice 2 — Loop refactor (M, 3h)

- Refactorizar `overnight-sprint` skill para lanzar subagentes frescos por tarea
- Model rotation: fast→mid→heavy si TOKEN_EXHAUSTION; abort para OOM/TIMEOUT
- Audit log: `output/agent-runs/overnight-{fecha}-audit.log` (ya existe schema en autonomous-safety.md)
- BATS: recovery desde estado parcial, model escalation, abort por max-failures

### Slice 3 — Aplicar a code-improvement-loop [diferido]

- Mismo patrón de loop stateless para code-improvement-loop
- Comparte `overnight-sprint-state.sh` como librería

## Risks

| Riesgo | Probabilidad | Mitigación |
|---|---|
| Subagente fresco no tiene contexto previo de la sesión | Alta | state.json incluye resumen de tareas anteriores como contexto seed |
| Loop lanza demasiados subagentes en paralelo | Media | Semáforo: max_parallel=1 por defecto, configurable |
| state.json corruption si crash durante write | Baja | Write atómico via tmp + mv |

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| overnight-sprint skill | `.opencode/skills/overnight-sprint/SKILL.md` | Skill registry |
| Loop script | `scripts/overnight-sprint-loop.sh` | Invocado via bash tool |
| State persistence | `scripts/overnight-sprint-state.sh` | Bash puro |

### Portability classification

- [x] **PURE_BASH**: loop y state management en bash stdlib. Sin bindings de frontend.
