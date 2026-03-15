---
id: "PBI-010"
title: "Database Index Optimization"
state: "Resolved"
type: "Tech Debt"
priority: "3-Medium"
assigned_to: "@alice"
story_points: 5
sprint: "Sprint 2026-04"
tags: [tech-debt, database, performance, sql]
specs: []
created: "2026-02-20"
updated: "2026-03-14"
---

## Descripcion

Query analyzer shows missing indexes on Orders.CreatedAt, AuditLogs.Timestamp, and Users.Email columns. These are high-traffic query paths causing full table scans on tables with 500K+ rows. Add covering indexes and verify execution plans.

## Criterios de Aceptacion

- [x] Index on Orders(CreatedAt DESC) with Include(Status, Total)
- [x] Index on AuditLogs(Timestamp DESC, Action)
- [x] Index on Users(Email) unique filtered (IsDeleted = 0)
- [x] EF Core migration created and tested against DEV
- [x] Query execution plans show Index Seek instead of Scan

## Tasks

- [TASK-010-001](../tasks/TASK-010-001-create-migration.md)

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-02-20 | @system | _created | — | — |
| 2026-03-11 | @alice | state | New | Active |
| 2026-03-14 | @alice | state | Active | Resolved |
