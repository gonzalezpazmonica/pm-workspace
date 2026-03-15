---
id: "TASK-006-001"
title: "RBAC backend: Role entity, policies, and CRUD API"
parent_pbi: "PBI-006"
type: "Development"
state: "Active"
assigned_to: "@carol"
estimated_hours: 12
remaining_hours: 5
sprint: "Sprint 2026-04"
tags: [rbac, auth, dotnet, api]
created: "2026-03-10"
updated: "2026-03-14"
---

## Descripcion

Create Role and Permission entities with EF Core migrations. Build RolesController with CRUD endpoints. Register authorization policies dynamically from DB permissions. Seed default roles: Admin, Manager, Analyst, Viewer.

## Registro de Horas

| Fecha | Persona | Horas | Nota |
|-------|---------|-------|------|
| 2026-03-11 | @carol | 4 | Entity models, migrations, and seeding |
| 2026-03-12 | @carol | 3 | RolesController CRUD endpoints |

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-03-10 | @system | _created | — | — |
| 2026-03-11 | @carol | state | New | Active |
