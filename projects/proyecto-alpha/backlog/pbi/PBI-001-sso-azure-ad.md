---
id: "PBI-001"
title: "SSO Authentication with Azure AD"
state: "Closed"
type: "User Story"
priority: "1-Critical"
assigned_to: "@alice"
story_points: 13
sprint: "Sprint 2026-03"
tags: [auth, sso, azure-ad, security]
specs: []
created: "2026-02-01"
updated: "2026-03-08"
---

## Descripcion

As a user I want to authenticate via Azure AD SSO so that I can use my corporate credentials without managing a separate password. The integration must support OIDC with PKCE flow, automatic token refresh, and group-based claim mapping.

## Criterios de Aceptacion

- [x] Users can log in with Azure AD corporate credentials
- [x] OIDC PKCE flow implemented in Angular 17 frontend
- [x] Token refresh happens transparently before expiry
- [x] Azure AD groups map to application roles
- [x] Logout clears both local and Azure AD session
- [x] Unit and integration tests cover auth flow

## Tasks

- [TASK-001-001](../tasks/TASK-001-001-implement-oidc-backend.md)
- [TASK-001-002](../tasks/TASK-001-002-angular-auth-interceptor.md)
- [TASK-001-003](../tasks/TASK-001-003-group-claim-mapping.md)

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-02-01 | @system | _created | — | — |
| 2026-02-03 | @carol | state | New | Active |
| 2026-03-05 | @alice | state | Active | Resolved |
| 2026-03-08 | @carol | state | Resolved | Closed |
