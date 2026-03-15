---
id: "TASK-008-001"
title: "Replace lazy loading with eager loading in OrderRepository"
parent_pbi: "PBI-008"
type: "Development"
state: "In Review"
assigned_to: "@eve"
estimated_hours: 4
remaining_hours: 1
sprint: "Sprint 2026-04"
tags: [ef-core, performance, eager-loading]
created: "2026-03-12"
updated: "2026-03-14"
---

## Descripcion

Refactor GetOrdersWithItems to use .Include(o => o.Items).ThenInclude(i => i.Product). Remove virtual keyword from navigation properties to prevent accidental lazy loading. Verify with SQL profiler that only 1 query is executed.

## Registro de Horas

| Fecha | Persona | Horas | Nota |
|-------|---------|-------|------|
| 2026-03-12 | @eve | 2 | Include chain and virtual removal |
| 2026-03-13 | @eve | 1 | SQL profiler verification |

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-03-12 | @system | _created | — | — |
| 2026-03-12 | @eve | state | New | Active |
| 2026-03-14 | @eve | state | Active | In Review |
