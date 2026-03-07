# /sdlc-advance

**Alias:** none
**Descripción:** Intenta avanzar una tarea al siguiente estado. Evalúa las puertas y muestra bloqueadores si no se cumplen.
**$ARGUMENTS:** task-id [--force]

## Parámetros

- `task-id` — Identificador de la tarea/PBI
- `--force` — Opcional. Evaluar puertas pero permitir fuerza (solo si autorizado)

## Flujo

1. Cargar estado actual y transición siguiente
2. Evaluar cada puerta de la transición
3. Si todas las puertas pasan → avanzar estado, registrar en auditoría
4. Si alguna puerta falla → mostrar bloqueadores y acciones recomendadas
5. Si `--force` → permitir avance pero registrar como "avance forzado" con actor

## Ejemplo de éxito

```
Task: PBI-001 | Estado: IN_PROGRESS

Evaluando puertas para: IN_PROGRESS → VERIFICATION

  ✅ Desarrollo completado — código integrado (todos commits merged)
  ✅ CI status: passing — builds sin errores

✅ AVANCE EXITOSO
  Estado anterior: IN_PROGRESS
  Estado nuevo: VERIFICATION
  Timestamp: 2026-03-07 11:30 UTC
  Actor: monica.gonzalez@company.com
```

## Ejemplo de bloqueadores

```
❌ NO SE PUEDE AVANZAR — Faltan requisitos

  Puerta 1: Especificación aprobada
    ❌ BLOQUEADOR — Campo approval_status ≠ approved
    Acción: Solicitar aprobación a architect en spec.md

  Puerta 2: Revisión de seguridad
    ❌ BLOQUEADOR — security_review != passed
    Acción: Ejecutar `/security-review PBI-001`

Siguiente paso: Completar acciones, luego `/sdlc-advance PBI-001`
