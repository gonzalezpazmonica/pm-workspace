---
name: sdlc-status
description: Show current SDLC state and transitions
---

---

# /sdlc-status

**Alias:** none
**Descripción:** Muestra el estado SDLC actual de una tarea o PBI, transiciones disponibles y requisitos de puertas.
**$ARGUMENTS:** task-id

## Parámetros

- `task-id` — Identificador de la tarea/PBI (e.g., PBI-001, AB#1234)

## Flujo

1. Buscar estado actual en `projects/{proyecto}/state/tasks/{task-id}.json`
2. Mostrar estado actual, transiciones y puertas
3. Mostrar acciones disponibles: `/sdlc-advance {task-id}`

## Ejemplo

Task: PBI-001 | Estado: SPEC_READY
- Transición siguiente: IN_PROGRESS
- Gate: Especificación aprobada ✅
- Gate: Revisión de seguridad ❌

Siguiente paso: `/sdlc-advance PBI-001`
