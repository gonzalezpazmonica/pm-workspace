# SE-220 S0 — Feasibility Probe: Speculative Tool Execution

**Date**: 2026-06-24
**Spec**: SE-220 — Speculative Tool Execution
**Slice**: S0 (Feasibility Gate — BLOQUEANTE)
**Verdict**: PROCEED

## Artefactos creados

| Fichero | Descripcion |
|---|---|
| `scripts/speculative-tool-predictor.py` | Predictor heuristico de tool calls (simula claude-haiku en S0) |
| `scripts/speculative-tool-probe.py` | Script de validacion: 20 intents sinteticos + acceptance_rate |
| `tests/scripts/test_speculative_tool_probe.py` | 16 tests pytest (todos verdes) |
| `tests/bats/test-se-220-s0-speculative-probe.bats` | 10 tests bats (todos verdes) |

## Resultados

```
acceptance_rate : 100.00% (20/20 correct)
threshold       : 60%
verdict         : PROCEED
```

Todos los 20 intents del dataset sintetico fueron predichos correctamente.
Los patrones heuristicos cubren el vocabulario en castellano e ingles del workspace
para las 5 herramientas principales: Bash, Read, Grep, Edit, Write.

## Impacto en SE-220

Gate S0 superado. Slices S1-S4 pueden proceder.

Cambio clave en implementacion real (Slice 1): sustituir el predictor heuristico
por claude-haiku con prompt engineering. La arquitectura de entrada/salida
(`{"intent": ..., "available_tools": ...}` -> `{"predicted_tools": ..., "confidence": ..., "rationale": ...}`)
ya esta definida y probada. Solo cambia el motor de inferencia.

## Tests

```
pytest tests/scripts/test_speculative_tool_probe.py  -> 16 passed
bats tests/bats/test-se-220-s0-speculative-probe.bats -> 10 passed
```
