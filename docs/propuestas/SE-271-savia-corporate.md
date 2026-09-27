# SE-271 — Savia Corporate

**Status:** PROPOSED · **Fecha:** 2026-07-25 · **Branch:** agent/se271-savia-corporate

> **2026-09-27 — implementación prematura retirada.** Los scripts de esta spec se habían mergeado sin aprobación (Rule 8) y sin ningún llamador; se retiraron en la consolidación de entropía SE-380. La spec sigue PROPOSED; recuperables desde git si se aprueba.

**Estimacion:** ~58h (7 slices) · **Base:** HEAD b415ba81

## Principio rector
El criterio corporativo se adopta; jamas se impone. Capa inerte por defecto.
Cuatro invariantes: monotonia, adopcion vinculada al encargo, visibilidad
sin control, resiliencia local.

## Origen
53 scripts en scripts/enterprise/ sin enforcement. rbac-model.md existe
(146 lineas) pero nada lo aplica. tenants/ son fixtures.

## Slices
S1: Modelo y monotonia (6h) — docs/corporate-model.md + gate de precedencia
S2: Adopcion (10h) — repo corporativo + adopcion entrada por entrada + ledger
S3: Murallas (14h) — 7 capas de aislamiento entre clientes + prueba de separacion
S4: Capacidades (10h) — enforcement real por encargo + reconciliar 53 scripts
S5: Atestacion (8h) — flota visible sin control de escritura
S6: Evidencia (6h) — paquete de compliance por cliente + 3 preguntas canonicas
S7: Resiliencia (4h) — corporativo caido nunca bloquea

## Out of scope
NO Modelo C. NO escritura corporativo→instancia. NO RBAC personal.
NO SSO/SCIM v1. NO fork.
