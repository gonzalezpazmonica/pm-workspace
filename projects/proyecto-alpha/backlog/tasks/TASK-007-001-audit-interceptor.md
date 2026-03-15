---
id: "TASK-007-001"
title: "EF Core SaveChanges interceptor for audit logging"
parent_pbi: "PBI-007"
type: "Development"
state: "Active"
assigned_to: "@dave"
estimated_hours: 8
remaining_hours: 4
sprint: "Sprint 2026-04"
tags: [audit, ef-core, interceptor, backend]
created: "2026-03-11"
updated: "2026-03-14"
---

## Descripcion

Create AuditSaveChangesInterceptor that hooks into SaveChangesAsync. For each tracked entity marked with [Auditable], capture old/new values, user ID from HttpContext, and write to AuditLog table. Handle bulk operations efficiently.

## Registro de Horas

| Fecha | Persona | Horas | Nota |
|-------|---------|-------|------|
| 2026-03-12 | @dave | 2 | Interceptor skeleton and entity detection |
| 2026-03-13 | @dave | 2 | Value diffing and HttpContext integration |

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-03-11 | @system | _created | — | — |
| 2026-03-12 | @dave | state | New | Active |
