---
id: "TASK-004-001"
title: "ReportsController with pagination and filtering"
parent_pbi: "PBI-004"
type: "Development"
state: "Done"
assigned_to: "@alice"
estimated_hours: 8
remaining_hours: 0
sprint: "Sprint 2026-04"
tags: [api, dotnet, controller, reporting]
created: "2026-03-10"
updated: "2026-03-13"
---

## Descripcion

Create ReportsController with GET /api/v1/reports supporting query params: from, to, sort, page, pageSize. Return PagedResult<ReportDto> with total count header. Include input validation.

## Registro de Horas

| Fecha | Persona | Horas | Nota |
|-------|---------|-------|------|
| 2026-03-10 | @alice | 4 | Controller, DTOs, and pagination logic |
| 2026-03-11 | @alice | 3 | Input validation and unit tests |
| 2026-03-13 | @alice | 1 | Code review fixes |

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-03-10 | @system | _created | — | — |
| 2026-03-10 | @alice | state | New | Active |
| 2026-03-13 | @alice | state | Active | Done |
