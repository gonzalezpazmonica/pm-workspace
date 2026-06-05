---
twin_id: "proyecto-alpha"
spec_version: "1.0"
last_refresh: "2026-06-05T16:27:48Z"
stale_after_days: 14
token_budget: 2000
health: yellow
predictions:
  sprint_slip:
    value: 0.3
    confidence: 0.7
    evidence_ref: "projects/proyecto-alpha/sprints/sprint-001/estado.md"
  next_blocker:
    value: "Módulo SSO pendiente de validación con proveedor externo"
    confidence: 0.8
    evidence_ref: "projects/proyecto-alpha/CLAUDE.md#SPRINT_GOAL"
  scope_drift:
    value: 0.1
    confidence: 0.6
    evidence_ref: "projects/proyecto-alpha/backlog"
  aggregate_health:
    value: yellow
    confidence: 0.75
    evidence_ref: "projects/proyecto-alpha/CLAUDE.md#VELOCITY_ULTIMA_SP"
---

## Estado

Sprint activo: Sprint 2026-04 (2026-03-02 → 2026-03-13).
Velocity última: 30 SP (media 32 SP, -6%).
Objetivo: Completar módulo autenticación SSO + dashboard usuario.
Bloqueantes: validación proveedor externo SSO pendiente.

## Reglas

Ver  para reglas completas.
Resumen: ciclo mínimo 2 semanas, WIP limit 3 items/desarrollador,
Definition of Done incluye tests e2e + revisión de seguridad.

## Predicciones

**Slip de sprint (confianza 0.70)**: probabilidad 0.30 de no cerrar
el sprint goal al 100%. El SSO lleva 2 días de bloqueo por validación
con proveedor externo; si no se resuelve en 24h el slip es inevitable.
Fuente: estado sprint-001.

**Próximo bloqueante (confianza 0.80)**: integración SSO con proveedor
externo. Acción recomendada: escalar hoy si no hay respuesta.
Fuente: CLAUDE.md SPRINT_GOAL.

**Drift de scope (confianza 0.60)**: mínimo (0.10). Backlog estable,
sin PBIs añadidos al sprint desde el planning.
Fuente: directorio backlog.

**Salud agregada (confianza 0.75)**: YELLOW. Velocity dentro de rango
pero bloqueante activo. Sin acción correctiva → RED en 48h.
Fuente: VELOCITY_ULTIMA_SP en CLAUDE.md.
