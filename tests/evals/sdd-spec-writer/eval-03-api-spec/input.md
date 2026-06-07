# Eval 03 — Spec de API paginada con filtros y ordenación

## Contexto

El equipo de PM-Workspace necesita un endpoint de listado para el catálogo de
agentes. La API debe soportar paginación con cursor (no offset), filtrado por
múltiples campos y ordenación dinámica. El volumen estimado es de 200-500 agentes,
pero el patrón debe escalar a 50.000 items sin degradación.

## Tarea para el agente sdd-spec-writer

Crea una spec ejecutable para el endpoint `GET /agents` con paginación basada
en cursor, filtros y ordenación. El endpoint acepta los query params:
- `cursor` (string, opaque, para paginación forward/backward)
- `limit` (int, 1-100, default 20)
- `filter[model]` (enum: fast, mid, heavy)
- `filter[permission]` (enum: L0, L1, L2, L3, L4)
- `sort` (string: name, model, createdAt; prefijo `-` para DESC)

La respuesta incluye `data` (array de agentes), `pagination.next_cursor`,
`pagination.prev_cursor`, `pagination.total_count` y `pagination.has_more`.

La spec debe especificar el comportamiento cuando el cursor es inválido o expirado
(400 con error code `CURSOR_INVALID`), cuando limit está fuera de rango (400), y
cuando se combinan múltiples filtros (AND lógico). Incluir al menos un ejemplo
completo de request/response en la spec.
