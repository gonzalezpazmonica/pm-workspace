---
context_tier: L2
spec: SE-230
token_budget: 900
---

# Auto-Loop Gate

## Que es y por que

Clasificador de peticiones que determina si una solicitud tiene un Criterio
de Convergencia verificable y qué skill de loop activar — sin que el usuario
deba conocer los skills disponibles.

## Tabla de decision

| Patron en la peticion | decision | loop_skill | max_iterations |
|---|---|---|---|
| spec + (test \| dod \| criterio \| acceptance) | PROPOSE_LOOP | tdd-vertical-slices | 8 |
| bug + (test \| reproduce \| falla) | PROPOSE_LOOP | tdd-vertical-slices | 5 |
| refactor + (coverage \| cobertura \| test) | PROPOSE_LOOP | code-improvement-loop | 6 |
| code review \| pr review | PROPOSE_LOOP | court-orchestrator | 3 |
| investiga/research/analiza + (fondo \| profundidad \| exhaustivo) | PROPOSE_LOOP | tech-research-agent | 4 |
| refactor sin test ni coverage | CLARIFY_NEEDED | — | — |
| todo lo demas | SINGLE_SHOT | — | — |

Guardia de recursion: si `SAVIA_LOOP_CONTEXT` esta seteado, el gate devuelve
siempre `SINGLE_SHOT`.

### Comportamiento con request vacío

`request=''` → `SINGLE_SHOT`, `rationale='empty request — no pattern to classify'`.

## Valores de decision

- `PROPOSE_LOOP` — DoD verificable; Savia muestra `proposal_text` y espera confirmacion.
- `SINGLE_SHOT` — respuesta directa, sin loop.
- `CLARIFY_NEEDED` — patron parcial; Savia pide aclaracion.

## Formato de salida (JSON)

```json
{
  "decision": "PROPOSE_LOOP",
  "loop_skill": "tdd-vertical-slices",
  "convergence_criterion": "tests_green_and_dod",
  "max_iterations": 8,
  "rationale": "Request contains spec SDD reference with verifiable DoD",
  "proposal_text": "Detecto que esta tarea tiene DoD verificable.\n  Loop sugerido: ...\n  ¿Activo el loop? [si / no / ajustar budget]"
}
```

## Ejemplo de uso

```bash
GATE=$(bash scripts/auto-loop-gate.sh --request "$USER_PROMPT")
DECISION=$(echo "$GATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['decision'])")
if [[ "$DECISION" == "PROPOSE_LOOP" ]]; then
  echo "$GATE" | python3 -c "import sys,json; print(json.load(sys.stdin)['proposal_text'])"
fi
```

## Como extender con nuevos patrones

Edita `scripts/auto-loop-gate.sh`, sección Decision table. Añade un `elif`
antes del bloque CLARIFY_NEEDED, registra el patron en la tabla superior y
añade casos en `tests/test-auto-loop-gate.bats`.

## Integracion con user-prompt-intercept.sh

El hook `user-prompt-intercept.sh` (SPEC-015) llama al gate si
`SAVIA_AUTO_LOOP=enabled`: invoca el script, y si `decision==PROPOSE_LOOP`
concatena `proposal_text` al output del turno.

### Integración SPEC-186

Cuando `decision=PROPOSE_LOOP`, el `proposal_text` es la primera confirmación.
La segunda confirmación es la activación explícita del skill con doble opt-in:

```bash
bash scripts/savia-double-optin-check.sh --skill <loop_skill> --confirm-autonomous
```

Sin la segunda confirmación el loop no arranca en modo autónomo.

## Relacion con otras specs

- `SPEC-RECURSION-GUARD`: `SAVIA_LOOP_CONTEXT` implementa el Subagent Scope Guard.
- `SPEC-TERMINAL-STATE-HANDOFF`: al agotar `max_iterations` el skill emite `DONE_WITH_CONCERNS`.
- `SPEC-186`: todos los skills activables por este gate requieren doble opt-in.

## Criterios de Aceptación

- [ ] AC-01: request con "spec" + "test" → `PROPOSE_LOOP`, `loop_skill=tdd-vertical-slices`
- [ ] AC-02: request con "bug" + "reproduce" → `PROPOSE_LOOP`, `loop_skill=tdd-vertical-slices`, `max_iterations=5`
- [ ] AC-03: request con "refactor" + "coverage" → `PROPOSE_LOOP`, `loop_skill=code-improvement-loop`
- [ ] AC-04: request con "code review" → `PROPOSE_LOOP`, `loop_skill=court-orchestrator`, `max_iterations=3`
- [ ] AC-05: request con "investiga" + "profundidad" → `PROPOSE_LOOP`, `loop_skill=tech-research-agent`
- [ ] AC-06: request con "refactor" sin criterio → `CLARIFY_NEEDED`
- [ ] AC-07: `SAVIA_LOOP_CONTEXT` seteado → `SINGLE_SHOT` siempre (recursión bloqueada)
- [ ] AC-08: request vacío → `SINGLE_SHOT` con `rationale="empty request"`
