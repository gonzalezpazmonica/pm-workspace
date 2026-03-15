---
id: "TASK-004-002"
title: "ReportService with detail and CSV export"
parent_pbi: "PBI-004"
type: "Development"
state: "Active"
assigned_to: "@alice"
estimated_hours: 10
remaining_hours: 6
sprint: "Sprint 2026-04"
tags: [api, dotnet, service, csv]
created: "2026-03-10"
updated: "2026-03-14"
---

## Descripcion

Implement ReportService with GetByIdAsync (full report with sections) and ExportCsvAsync (streaming CSV response). Service layer handles business logic and delegates to ReportRepository.

## Registro de Horas

| Fecha | Persona | Horas | Nota |
|-------|---------|-------|------|
| 2026-03-13 | @alice | 2 | GetByIdAsync with section mapping |
| 2026-03-14 | @alice | 2 | CSV export streaming setup |

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-03-10 | @system | _created | — | — |
| 2026-03-13 | @alice | state | New | Active |
