---
name: sdlc-advance
description: Advance work item through SDLC state machine
---

---

# /sdlc-advance

**Alias:** none
**Descripción:** Intenta avanzar una tarea al siguiente estado evaluando puertas.
**$ARGUMENTS:** task-id [--force]

## Parámetros

- `task-id` — Identificador de la tarea/PBI
- `--force` — Permitir avance forzado registrando como excepción

## Flujo

1. Cargar estado actual y transición siguiente
2. Evaluar cada puerta de la transición
3. Si todas pasan → avanzar, registrar en auditoría
4. Si alguna falla → mostrar bloqueadores

## Ejemplo éxito

Task: PBI-001 | IN_PROGRESS → VERIFICATION
✅ Desarrollo completado — código integrado
✅ CI status: passing
✅ AVANCE EXITOSO — 2026-03-07 11:30 UTC
