---
context_tier: L2
spec: SE-230
token_budget: 900
---

# Auto-Loop Gate

## Que es y por que

El Auto-Loop Gate es un clasificador de peticiones que determina si una
solicitud del usuario tiene un Criterio de Convergencia verificable y, si
lo tiene, que skill de loop debe activarse — evitando que el usuario
necesite conocer los skills disponibles.

Sin esta capa, el usuario debe saber que existe tdd-vertical-slices o
court-orchestrator. Con ella, Savia detecta el patron, propone el loop
adecuado y espera confirmacion antes de activarlo.

## Tabla de decision

| Patron en la peticion | decision | loop_skill | max_iterations |
|---|---|---|---|
| spec + (test | dod | criterio | acceptance) | PROPOSE_LOOP | tdd-vertical-slices | 8 |
| bug + (test | reproduce | falla) | PROPOSE_LOOP | tdd-vertical-slices | 5 |
| refactor + (coverage | cobertura | test) | PROPOSE_LOOP | code-improvement-loop | 6 |
| code review | pr review | PROPOSE_LOOP | court-orchestrator | 3 |
| investiga/research/analiza + (fondo | profundidad | exhaustivo) | PROPOSE_LOOP | tech-research-agent | 4 |
| refactor sin test ni coverage | CLARIFY_NEEDED | — | — |
| todo lo demas | SINGLE_SHOT | — | — |

Guardia de recursion: si SAVIA_LOOP_CONTEXT esta seteado (ya estamos
dentro de un loop), el gate devuelve siempre SINGLE_SHOT.

## Valores de decision

- PROPOSE_LOOP — la peticion tiene DoD verificable; Savia muestra proposal_text y espera confirmacion.
- SINGLE_SHOT — respuesta directa, sin loop.
- CLARIFY_NEEDED — patron parcial detectado (ej. refactor sin criterio); Savia pide aclaracion.

## Formato de salida (JSON)

```
{
  "decision": "PROPOSE_LOOP",
  "loop_skill": "tdd-vertical-slices",
  "convergence_criterion": "tests_green_and_dod",
  "max_iterations": 8,
  "rationale": "Request contains spec SDD reference with verifiable DoD",
  "proposal_text": "Detecto que esta tarea tiene DoD verificable.\n  Loop sugerido: ...\n  Criterio de parada: ...\n  Budget maximo: N iteraciones\n\n¿Activo el loop? [si / no / ajustar budget]"
}
```

## Ejemplo de uso

```bash
# Invocacion directa
bash scripts/auto-loop-gate.sh --request "implementa la spec SE-200 con tests y dod"

# Desde hook
GATE=$(bash scripts/auto-loop-gate.sh --request "$USER_PROMPT")
DECISION=$(echo "$GATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['decision'])")
if [[ "$DECISION" == "PROPOSE_LOOP" ]]; then
  echo "$GATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['proposal_text'])"
fi
```

## Como extender con nuevos patrones

Edita scripts/auto-loop-gate.sh, seccion Decision table.
Agrega un bloque elif antes del bloque CLARIFY_NEEDED:

```bash
elif has '\b(patron1|patron2)\b' && has '\b(criterio1|criterio2)\b'; then
  DECISION="PROPOSE_LOOP"
  LOOP_SKILL="nombre-del-skill"
  CONVERGENCE="criterio_de_convergencia"
  MAX_ITER=N
  RATIONALE="Descripcion del patron detectado"
```

Agrega el criterion_label correspondiente en la funcion homónima.
Registra el nuevo patron en la tabla de decision de este fichero.

## Integracion con user-prompt-intercept.sh

El hook user-prompt-intercept.sh (SPEC-015) puede llamar al gate si
SAVIA_AUTO_LOOP=enabled. La seccion al final del hook:

1. Invoca auto-loop-gate.sh --request "$INPUT_TEXT".
2. Si decision == PROPOSE_LOOP, concatena proposal_text al OUTPUT
   que el hook inyecta como contexto del turno.
3. El modelo ve la propuesta antes de responder y puede activar el loop.

Fichero temporal: $SAVIA_TMP/auto-loop-proposal-$$.txt para turnos
donde el hook no soporta stdout directo.

## Relacion con otras specs

- SPEC-RECURSION-GUARD: la guardia SAVIA_LOOP_CONTEXT implementa la
  misma logica que el Subagent Scope Guard de autonomous-safety.md —
  un loop no puede lanzar otro loop.
- SPEC-TERMINAL-STATE-HANDOFF: cuando max_iterations se agota sin
  convergencia, el skill activo debe emitir DONE_WITH_CONCERNS y devolver
  control al usuario. El gate fija el budget maximo como contrato.
- SPEC-186 doble opt-in: los skills activables por este gate
  (tdd-vertical-slices, code-improvement-loop, overnight-sprint)
  requieren confirmacion explicita ademas de la propuesta del gate.
  El proposal_text sirve como primera confirmacion; la segunda
  la exige el skill en su propio arranque.
