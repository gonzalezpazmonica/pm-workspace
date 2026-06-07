# Eval 03 — Verificación de compliance entre implementación y spec aprobada

## Contexto

El equipo ha implementado el endpoint POST /invoices según la spec SE-190.
El court-orchestrator debe verificar que la implementación cumple exactamente
con los criterios de aceptación de la spec aprobada, usando el juez spec-judge
como principal árbitro.

## Spec aprobada (fragmento relevante)

La spec SE-190 define los siguientes criterios de aceptación para POST /invoices:
- AC1: El endpoint acepta campos: customer_id (UUID, obligatorio), items (array, mínimo 1 elemento), currency (enum: EUR/USD, default EUR)
- AC2: Si customer_id no existe, devuelve 404 con error code CUSTOMER_NOT_FOUND
- AC3: Si items está vacío, devuelve 400 con error code ITEMS_REQUIRED
- AC4: El total de la factura se calcula sumando (quantity * unit_price) de cada item
- AC5: La factura creada tiene status DRAFT y devuelve 201 con el objeto completo

## Descripción de la implementación entregada

El equipo implementó el endpoint con estas diferencias respecto a la spec:
- currency acepta EUR/USD/GBP (la spec no incluye GBP)
- Cuando items está vacío devuelve 422 en lugar de 400
- El error code para items vacío es VALIDATION_ERROR en lugar de ITEMS_REQUIRED
- El total se calcula correctamente
- El status DRAFT y el código 201 están correctamente implementados
- customer_id se valida correctamente con 404 y CUSTOMER_NOT_FOUND

## Tarea para el court-orchestrator

Ejecuta el Code Review Court con foco en spec-compliance. Determina:
- Qué ACs están completamente implementados
- Qué ACs tienen desviaciones respecto a la spec
- Si las desviaciones son bloqueantes para el merge
- El veredicto final y las correcciones requeridas
