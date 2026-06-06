---
context_tier: L2
token_budget: 800
spec: SPEC-188
phase: 0
created: 2026-06-06
---

# Feedback Root Cause Always — Savia Memory Rule

Cuando Savia detecta un fallo repetido, SIEMPRE registrar la causa raíz en memoria
antes de continuar. Nunca parchear síntomas sin documentar la causa.

## Regla

Formato obligatorio al registrar un fallo recurrente:

```
root_cause: <causa>
pattern: <patrón>
prevention: <acción preventiva>
```

## Ejemplos

**Ejemplo 1 — threshold bajado sin causa**
```
root_cause: test falla con score real 72/100, umbral estaba en 80
pattern: agente baja umbral para pasar CI en vez de arreglar código
prevention: investigar por qué el score bajó antes de tocar el umbral
```
**Ejemplo 2 — retry sin cambio causal**
```
root_cause: push rechazado por hook de firmas; agente reintentó 6 veces
pattern: mismo parche superficial repetido sin alterar hipótesis causal
prevention: tras attempt 3 del mismo target, parar y razonar (SPEC-065)
```
**Ejemplo 3 — spec marcada IMPLEMENTED sin ACs completos**
```
root_cause: 2 de 5 ACs no pasan; agente marcó IMPLEMENTED de todas formas
pattern: spec status actualizado antes de validar criterios de aceptación
prevention: IMPLEMENTED solo si TODOS los ACs verificados con evidencia
```

## Patrones prohibidos

1. Bajar umbral sin `Causal-Evidence:` documentado.
2. `pytest.mark.skip` / `xfail` sin issue tracked + root cause.
3. Retry N=3+ del mismo action+target con variantes superficiales.
4. `--no-verify` en commits o push (hooks existen por algo).
5. Modificar assertion en test para que pase.
6. Marcar SPEC IMPLEMENTED con ACs incompletos.

## Consumidores

- `memory-conflict-judge` (SPEC-125): veto si recomendación viola estos patrones.
- `responsibility-judge` (SPEC-043): bloquea PreToolUse shortcut patterns.
- `execution-supervisor` (SPEC-065): exhibe esta memoria tras attempt 3.

Ref: SPEC-188 Fase 0 — cierre hallazgo G3. Path canónico: `.claude/rules/domain/feedback/` (N1).
