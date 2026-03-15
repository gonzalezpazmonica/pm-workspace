---
id: "PBI-008"
title: "Fix N+1 Query in OrderRepository"
state: "Active"
type: "Bug"
priority: "1-Critical"
assigned_to: "@eve"
story_points: 5
sprint: "Sprint 2026-04"
tags: [bug, performance, ef-core, backend]
specs: []
created: "2026-03-02"
updated: "2026-03-14"
---

## Descripcion

The OrderRepository.GetOrdersWithItems() method triggers N+1 queries due to lazy loading of OrderItem navigation property. On pages with 50+ orders this causes 3-5 second response times. Fix with eager loading (.Include) and verify with SQL profiler.

## Criterios de Aceptacion

- [x] GetOrdersWithItems uses .Include(o => o.Items) eager loading
- [ ] Response time for 100 orders < 500ms (currently ~4200ms)
- [ ] No new lazy loading violations in OrderRepository
- [ ] SQL profiler log shows single query instead of N+1
- [ ] Regression test validates query count

## Tasks

- [TASK-008-001](../tasks/TASK-008-001-eager-loading-fix.md)
- [TASK-008-002](../tasks/TASK-008-002-perf-regression-test.md)

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-03-02 | @system | _created | — | — |
| 2026-03-02 | @carol | priority | 2-High | 1-Critical |
| 2026-03-12 | @eve | state | New | Active |
