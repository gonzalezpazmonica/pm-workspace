---
id: "PBI-002"
title: "User Dashboard with KPI Widgets"
state: "Closed"
type: "User Story"
priority: "2-High"
assigned_to: "@bob"
story_points: 8
sprint: "Sprint 2026-03"
tags: [frontend, dashboard, kpi, angular]
specs: []
created: "2026-02-01"
updated: "2026-03-10"
---

## Descripcion

As a manager I want a dashboard with configurable KPI widgets so that I can monitor key business metrics at a glance. Widgets include bar charts, line charts, and summary cards backed by the reporting API.

## Criterios de Aceptacion

- [x] Dashboard page renders with a 3-column responsive grid
- [x] At least 4 widget types: summary card, bar chart, line chart, table
- [x] Widgets load data from /api/v1/kpi endpoints
- [x] Loading and error states handled gracefully
- [x] Accessible: WCAG AA contrast, keyboard navigable

## Tasks

- [TASK-002-001](../tasks/TASK-002-001-dashboard-layout.md)
- [TASK-002-002](../tasks/TASK-002-002-kpi-widgets.md)

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-02-01 | @system | _created | — | — |
| 2026-02-10 | @bob | state | New | Active |
| 2026-03-07 | @bob | state | Active | Resolved |
| 2026-03-10 | @carol | state | Resolved | Closed |
