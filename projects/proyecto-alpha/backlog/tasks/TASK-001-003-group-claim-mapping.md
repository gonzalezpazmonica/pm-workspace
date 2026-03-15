---
id: "TASK-001-003"
title: "Azure AD group-to-role claim mapping"
parent_pbi: "PBI-001"
type: "Development"
state: "Done"
assigned_to: "@alice"
estimated_hours: 6
remaining_hours: 0
sprint: "Sprint 2026-03"
tags: [auth, azure-ad, claims, dotnet]
created: "2026-02-03"
updated: "2026-03-05"
---

## Descripcion

Map Azure AD security groups to application roles via ClaimsTransformation middleware. Groups are resolved from the Graph API on first login and cached in the user session.

## Registro de Horas

| Fecha | Persona | Horas | Nota |
|-------|---------|-------|------|
| 2026-02-24 | @alice | 3 | Claims transformation and Graph API call |
| 2026-02-25 | @alice | 2 | Caching layer and unit tests |
| 2026-03-05 | @alice | 1 | Final integration test |

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-02-03 | @system | _created | — | — |
| 2026-02-24 | @alice | state | New | Active |
| 2026-03-05 | @alice | state | Active | Done |
