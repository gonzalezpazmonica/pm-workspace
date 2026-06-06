---
context_tier: L2
token_budget: 537
---

# Protocolo de Fan-out Paralelo para Tribunales (SPEC-159)

> Referencia: `docs/propuestas/SPEC-159-async-tribunal-fanout.md`
> Aplica a: `court-orchestrator`, `truth-tribunal-orchestrator`,
> `recommendation-tribunal-orchestrator`.

## Principio

Los jueces son independientes entre sí. La ejecución secuencial multiplica
el tiempo de pared por el número de jueces. El protocolo estándar lanza
todos los jueces en un único turno con múltiples llamadas Task simultáneas.

## Instrucción para orchestradores

**Lanzar todos los jueces en un único mensaje con múltiples tool calls en paralelo.**

```
# Correcto — un único mensaje, N Task calls simultáneos:
Task(judge="factuality-judge",   input={diff, spec, type})
Task(judge="hallucination-judge", input={diff, spec, type})
Task(judge="coherence-judge",     input={diff, spec, type})
Task(judge="completeness-judge",  input={diff, spec, type})

# Incorrecto — un mensaje por juez → ejecución secuencial → N × wall-time:
# Task("factuality-judge", ...)   # esperar
# Task("hallucination-judge", ...) # esperar
```

## Semántica de vetos

La paralelización no cambia la semántica de vetos:

- Recoger todos los veredictos antes de agregar resultados.
- Si cualquier juez emite BLOCK → abortar con exit 1.
- Si cualquier juez supera `SAVIA_TRIBUNAL_TIMEOUT` (default 60 s) → BLOCK.
- Registrar tiempo individual por juez + tiempo total de pared.

## Modo secuencial (fallback)

Cuando el entorno no soporta paralelismo (LocalAI, single-shot mode):

```bash
bash scripts/tribunal-async-runner.sh --mode sync judge1 judge2 judge3
export SAVIA_TRIBUNAL_MODE=sync  # alternativa
```

Ver `scripts/tribunal-async-runner.sh` y `docs/rules/domain/subagent-fallback-mode.md`.

## Aplicación por orchestrador

| Orchestrador | Jueces en paralelo |
|---|---|
| `court-orchestrator` | 4 internos (+ pr-agent si `COURT_INCLUDE_PR_AGENT=true`) |
| `truth-tribunal-orchestrator` | 7 jueces independientes |
| `recommendation-tribunal-orchestrator` | 4 jueces rápidos |

## Impacto esperado

Cuatro jueces a ~30 s/juez: secuencial ~120 s → paralelo ~30–40 s (≥60 % reducción).
