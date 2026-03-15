---
id: "PBI-007"
title: "Audit Trail for Sensitive Operations"
state: "Active"
type: "User Story"
priority: "2-High"
assigned_to: "@dave"
story_points: 8
sprint: "Sprint 2026-04"
tags: [audit, security, backend, compliance]
specs: []
created: "2026-02-28"
updated: "2026-03-14"
---

## Descripcion

As a compliance officer I want an immutable audit trail of all sensitive operations (user creation, role changes, report deletion, data export) so that we can demonstrate regulatory compliance during audits.

## Criterios de Aceptacion

- [x] AuditLog entity with timestamp, userId, action, resource, details
- [ ] EF Core interceptor captures Create/Update/Delete on audited entities
- [ ] GET /api/v1/audit-logs with date range and action type filters
- [ ] Logs are append-only: no update or delete endpoints
- [ ] Retention policy: 3 years, configurable in appsettings

## Tasks

- [TASK-007-001](../tasks/TASK-007-001-audit-interceptor.md)
- [TASK-007-002](../tasks/TASK-007-002-audit-api.md)

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-02-28 | @system | _created | — | — |
| 2026-03-11 | @dave | state | New | Active |
