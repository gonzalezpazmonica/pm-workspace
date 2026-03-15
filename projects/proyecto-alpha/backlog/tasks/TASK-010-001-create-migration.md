---
id: "TASK-010-001"
title: "EF Core migration for database indexes"
parent_pbi: "PBI-010"
type: "Development"
state: "Done"
assigned_to: "@alice"
estimated_hours: 4
remaining_hours: 0
sprint: "Sprint 2026-04"
tags: [ef-core, migration, sql, indexes]
created: "2026-03-11"
updated: "2026-03-14"
---

## Descripcion

Create EF Core migration AddPerformanceIndexes with 3 indexes: Orders(CreatedAt DESC) INCLUDE (Status, Total), AuditLogs(Timestamp DESC, Action), Users(Email) WHERE IsDeleted = 0. Test against DEV database and verify execution plans.

## Registro de Horas

| Fecha | Persona | Horas | Nota |
|-------|---------|-------|------|
| 2026-03-12 | @alice | 2 | Migration creation and local testing |
| 2026-03-14 | @alice | 2 | DEV deployment and execution plan verify |

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-03-11 | @system | _created | — | — |
| 2026-03-12 | @alice | state | New | Active |
| 2026-03-14 | @alice | state | Active | Done |
