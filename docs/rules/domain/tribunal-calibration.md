---
context_tier: L3
token_budget: 1473
---

# Tribunal Calibration — Memory feedback loop sin reentreno

> **SPEC**: SPEC-125 seccion 6 (`docs/propuestas/SPEC-125-recommendation-tribunal-realtime.md`)
> **Slice**: 3 — Memory feedback loop.
> **Status**: canonical. **NO ACTIVADO POR DEFECTO** (mismo gate que la regla madre `recommendation-tribunal.md`).
> **Sister rule**: `docs/rules/domain/recommendation-tribunal.md` (foundation), `docs/rules/domain/radical-honesty.md`.

## Tesis (un parrafo)

El Recommendation Tribunal de Slice 1+2 emite veredictos `PASS / WARN / VETO` sobre cada recomendacion accionable de Savia. Pero el tribunal puede equivocarse en dos direcciones: **falso positivo** (vetar advice que era correcto, generando friccion innecesaria) y **falso negativo** (dejar pasar advice que era incorrecto, fallando en su mision). Slice 3 cierra ese loop sin reentrenar el modelo: captura la reaccion del usuario al banner del tribunal en el siguiente turno, la clasifica como `fp / fn / neutral`, y deriva una **feedback memory** estructurada que los jueces leen en turns futuros como contexto adicional. Es aprendizaje por contexto, no por gradient descent — preserva la sovereignty del usuario sobre la calibracion.

## Por que memory feedback en lugar de re-entreno

| Via | Ventaja | Desventaja | Decision SPEC-125 |
|---|---|---|---|
| **Re-entrenar el modelo subyacente** | Calibracion profunda | Caro, lento, requiere infra ML, opaco al usuario, no reversible | Rechazado |
| **Re-entrenar pesos del orchestrator** | Mas rapido | Sigue siendo opaco; introduce una pieza ML separada | Rechazado |
| **Memory-as-context** | Transparente, auditable, reversible (borrar el .md lo deshace), portable a LocalAI | El modelo lo "ve" como contexto, no como pesos | **Adoptada** |

La feedback memory es, deliberadamente, la misma capa que ya usa Savia para los `feedback_*.md` files existentes. El tribunal no inventa una capa nueva; consume y produce en la capa que ya existe.

## Componentes Slice 3

| Tipo | Path | Rol |
|---|---|---|
| Hook | `.opencode/hooks/recommendation-tribunal-followup.sh` | WIRE-READY (NO-OP por defecto). Cuando se activa, lee el siguiente prompt del usuario tras un turn con banner y delega al recorder. |
| Recorder | `scripts/recommendation-tribunal/followup-record.sh` | Anota la respuesta del usuario en el JSON record original. |
| Calibrator | `scripts/recommendation-tribunal/calibrate.sh` | Procesa records con clasificacion fp/fn y emite feedback memories. Idempotente. |
| Tests | `tests/test-spec-125-slice-3-memory-feedback-loop.bats` | BATS suite con regression tests sobre los patterns reportados en SPEC-125. |

## Heuristica de clasificacion (followup-record.sh)

El recorder clasifica la respuesta del usuario al banner sin LLM, por keyword matching:

- **fp (false positive)** — el usuario rebate el VETO o WARN.
- **fn (false negative)** — el usuario reporta que el PASS fue incorrecto.
- **neutral** — ningun patron matched. No hay senal de calibracion.

La heuristica es deliberadamente conservadora: prefiere `neutral` ante ambiguedad.

## Pipeline de calibracion

```
[turn N]
  Savia draft -> tribunal -> banner -> output al usuario
                          +
                          +--> output/recommendation-tribunal/<date>/<hash>.json

[turn N+1]
  user prompt -> hook followup (si activado)
                  -> followup-record.sh --hash <last_hash> --text "<reply>"
                  -> JSON record actualizado con user_response_*

[batch async]
  calibrate.sh
    -> lee records con classification fp o fn
    -> emite feedback_tribunal_calibration_<class>_<hash>.md

[turn N+M]
  jueces leen contexto, incluyen feedback memories.
  Ajuste:
    - fp memories: relaja VETO a WARN para el mismo pattern.
    - fn memories: eleva sensibilidad para el mismo pattern.
```

## Politica de emision de memorias

`calibrate.sh` emite **una memoria por record** con clasificacion `fp` o `fn`. La memoria contiene:

1. **Pattern** — que dice la calibracion en una frase.
2. **Original draft (preview)** — los primeros 160 caracteres del borrador.
3. **Original verdict** — `verdict` y `risk_class` del record.
4. **User followup** — los primeros 300 caracteres del texto del usuario.
5. **Calibration directive for future judges** — instruccion concreta.

Los jueces, al leer estas memorias en turns futuros, deben citarlas explicitamente en el banner cuando ajusten su veredicto.

## Reversibilidad

Borrar los archivos `feedback_tribunal_calibration_*.md` revierte la calibracion derivada. La calibracion nunca es destructiva sobre el estado del modelo.

## Auditabilidad

Cada feedback memory derivada referencia su record fuente por `draft_hash` (12-char prefix en el filename). El usuario puede usar:

```
bash scripts/recommendation-tribunal-search.sh --hash <prefix>
```

para ver el record original.

## Anti-patterns que esta regla prohibe

1. **Calibracion silenciosa** — el tribunal NO debe ajustar veredictos sin citar la memoria que justifica el ajuste.
2. **Auto-emision de memorias sin clasificacion** — la heuristica prefiere `neutral` ante ambiguedad. NO se emiten memorias por inferencia LLM unsupervised.
3. **Re-emision sobre el mismo record** — `calibrate.sh` es idempotente.
4. **Calibracion cross-user** — las memorias viven en el directorio del usuario activo, no en el repo publico.

## Activacion

Mismo gate que la regla madre. Para activar el hook de followup, el usuario debe editar `.claude/settings.json` manualmente y exportar `RECOMMENDATION_TRIBUNAL_FOLLOWUP_ACTIVE=1`.

## Referencias

- SPEC-125 sec 6 (Memory feedback loop) y sec 8 (Audit trail).
- `docs/rules/domain/recommendation-tribunal.md` — regla madre (foundation Slice 1).
- `docs/rules/domain/radical-honesty.md` — Rule sobre honestidad radical, base epistemologica del tribunal.
- `docs/memory-system.md` — capa de memory-as-context.
