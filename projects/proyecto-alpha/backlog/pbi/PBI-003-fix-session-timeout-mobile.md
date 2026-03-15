---
id: "PBI-003"
title: "Fix session timeout on mobile browsers"
state: "Closed"
type: "Bug"
priority: "1-Critical"
assigned_to: "@dave"
story_points: 3
sprint: "Sprint 2026-03"
tags: [bug, auth, mobile, session]
specs: []
created: "2026-02-12"
updated: "2026-03-06"
---

## Descripcion

Mobile users are logged out after 2 minutes of inactivity instead of the configured 30-minute timeout. Root cause: the background tab throttling in mobile Safari and Chrome prevents the token refresh timer from firing. Fix must use Service Worker or visibility API fallback.

## Criterios de Aceptacion

- [x] Session persists for 30 min of inactivity on iOS Safari
- [x] Session persists for 30 min of inactivity on Android Chrome
- [x] Token refresh triggers on tab visibility change
- [x] Regression test covers mobile timeout scenario

## Tasks

- [TASK-003-001](../tasks/TASK-003-001-visibility-api-refresh.md)

## Historial

| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-02-12 | @system | _created | — | — |
| 2026-02-12 | @carol | priority | 2-High | 1-Critical |
| 2026-02-14 | @dave | state | New | Active |
| 2026-03-04 | @dave | state | Active | Resolved |
| 2026-03-06 | @carol | state | Resolved | Closed |
