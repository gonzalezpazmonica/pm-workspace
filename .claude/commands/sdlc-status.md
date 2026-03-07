# /sdlc-status

**Alias:** none
**Descripción:** Muestra el estado SDLC actual de una tarea o PBI, transiciones disponibles y requisitos de puertas.
**$ARGUMENTS:** task-id

## Parámetros

- `task-id` — Identificador de la tarea/PBI (e.g., PBI-001, AB#1234)

## Flujo

1. Buscar estado actual en `projects/{proyecto}/state/tasks/{task-id}.json`
2. Si no existe → crear fichero de estado inicial (BACKLOG)
3. Mostrar:
   - **Estado actual**: nombre del estado, timestamp
   - **Transiciones disponibles**: estados a los que se puede pasar
   - **Puertas (Gates)**: requisitos para cada transición con estado de cumplimiento
   - **Historial**: últimas 3 transiciones con actor y resultado
4. Mostrar acciones disponibles: `/sdlc-advance {task-id}`

## Ejemplo

```
Task: PBI-001 | Sprint: S2026-04

Estado actual: SPEC_READY (desde 2026-03-05 10:00)
Última transición: DECOMPOSED → SPEC_READY (jane@example.com, exitosa)

Transiciones disponibles:
  → IN_PROGRESS (próximo estado)
    Gate: Especificación aprobada ✅ (aprobada 2026-03-05)
    Gate: Revisión de seguridad ❌ (pendiente)
```

**Siguiente paso:** `/sdlc-advance PBI-001` para evaluar puertas y avanzar.
