---
id: "TASK-008-002"
title: "Performance regression test for order queries"
parent_pbi: "PBI-008"
type: "Testing"
state: "Active"
assigned_to: "@eve"
estimated_hours: 4
remaining_hours: 2
sprint: "Sprint 2026-04"
tags: [testing, performance, ef-core, benchmark]
created: "2026-03-12"
updated: "2026-03-14"
---

## Descripcion

Create integration test that seeds 200 orders with items, executes GetOrdersWithItems, and asserts: response time < 500ms and exactly 1 SQL query executed. Use TestContainers with SQL Server image.

## Registro de Horas

| Fecha | Persona | Horas | Nota |
|-------|---------|-------|------|
| 2026-03-14 | @eve | 2 | TestContainers setup and seed data |

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-03-12 | @system | _created | — | — |
| 2026-03-14 | @eve | state | New | Active |
