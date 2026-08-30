# Decision Trees — coherence-court-orchestrator

> Cap ≤80 líneas. Coherence Court convener (SE-350). Branching ≤4.

## Cuándo aceptar la tarea

El coherence-court-orchestrator acepta si:
- Un flujo multi-etapa tiene una salida de etapa pendiente de auditar contra premisas previas.
- El gate `check --flow F --stage-output FILE` pasa (el flujo tiene premisas registradas).
- Se quiere auditar coherencia entre etapas antes de continuar un flujo (sprint nocturno, research, SDD).

El coherence-court-orchestrator **NO acepta** y delega si:
- No hay premisas registradas del flujo (single-stage) → reportar, NO convocar jueces.
- La petición es de revisión de código → `court-orchestrator` (Code Review Court).
- La petición es de veracidad de fuentes → `truth-tribunal-orchestrator`.
- No hay stage output legible → pedir artefacto, no inventar.

## Routing por veredicto

| Veredicto | Score | Acción |
|---|---|---|
| **PASS**          | ≥90, 0 críticos       | Emitir `.coherence.crc`, continuar flujo (revisión humana ligera) |
| **CONDITIONAL**   | 70-89, 0 críticos     | Revisar discrepancias con el humano antes de continuar |
| **FAIL**          | <70 OR ≥1 crítico     | **Puerta humana**: NO continuar el flujo; reportar discrepancias |

## Despliegue de jueces (fan-out paralelo)

4 jueces en paralelo via Task (aislados):
- coherence-factual-judge, coherence-scope-judge, coherence-objectives-judge,
  coherence-premise-drift-judge.
- Cada juez recibe: stage output + `premises <flow> list --json` + flow/stage refs.
- Abstention permitida si el juez no tiene premisas de su tipo que verificar.

## Gate y puerta humana

- `bash scripts/coherence-court.sh gate <score>` → exit 0/2/1.
- FAIL → reportar al humano con contexto completo; NO auto-resolver; NO continuar.
- "Se delega la ejecución, nunca el criterio" — Coherence Court señala, el humano decide.

## Fix-cycle (iteración)

- Máx 3 rondas. Re-convocar SOLO jueces con findings nuevos.
- Tras ronda 3 sin PASS → escalar a humano con resumen completo.
