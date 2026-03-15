---
id: "PBI-006"
title: "Role-Based Access Control"
state: "Active"
type: "User Story"
priority: "1-Critical"
assigned_to: "@carol"
story_points: 13
sprint: "Sprint 2026-04"
tags: [auth, rbac, security, backend, frontend]
specs: []
created: "2026-02-25"
updated: "2026-03-14"
---

## Descripcion

As an admin I want to manage user roles and permissions so that each user only sees and edits what their role allows. Roles: Admin, Manager, Analyst, Viewer. Permissions enforced at API and UI level.

## Criterios de Aceptacion

- [x] Role entity with CRUD endpoints under /api/v1/roles
- [ ] Permission matrix stored in DB, editable by Admin
- [ ] API endpoints enforce role checks via [Authorize(Policy=...)]
- [ ] Angular route guards hide unauthorized navigation items
- [ ] Audit log entry created on every permission change

## Tasks

- [TASK-006-001](../tasks/TASK-006-001-rbac-backend.md)
- [TASK-006-002](../tasks/TASK-006-002-rbac-frontend-guards.md)
- [TASK-006-003](../tasks/TASK-006-003-rbac-permission-audit.md)

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-02-25 | @system | _created | — | — |
| 2026-03-10 | @carol | state | New | Active |
