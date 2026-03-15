---
id: "PBI-004"
title: "REST API for Reporting Module"
state: "Active"
type: "User Story"
priority: "2-High"
assigned_to: "@alice"
story_points: 13
sprint: "Sprint 2026-04"
tags: [api, reporting, dotnet, backend]
specs: []
created: "2026-02-20"
updated: "2026-03-14"
---

## Descripcion

As a frontend developer I need a set of REST endpoints under /api/v1/reports so that the Angular client can fetch, filter, and paginate report data. Endpoints must support date-range filtering, column sorting, and CSV export header.

## Criterios de Aceptacion

- [x] GET /api/v1/reports returns paginated list with total count
- [x] Query params: from, to, sort, page, pageSize
- [ ] GET /api/v1/reports/{id} returns full report with sections
- [ ] Accept: text/csv triggers CSV download
- [ ] Authorization: only users with ReportReader role can access

## Tasks

- [TASK-004-001](../tasks/TASK-004-001-report-controller.md)
- [TASK-004-002](../tasks/TASK-004-002-report-service.md)
- [TASK-004-003](../tasks/TASK-004-003-report-authorization.md)

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-02-20 | @system | _created | — | — |
| 2026-03-10 | @alice | state | New | Active |
