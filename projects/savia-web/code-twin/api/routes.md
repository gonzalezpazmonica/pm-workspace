---
module_id: ApiRoutes
layer: api
version: "1.0.0"
last_sync: "2026-06-06T10:00:00Z"
token_budget: 400
stale_after_days: 14
depends_on:
  - FrontendComposables
provides:
  - GET /backlog
  - GET /dashboard
  - POST /auth/login
  - GET /auth/me
  - GET /telemetry
status: STABLE
---
# API Routes — savia-web

All routes proxied via `useBridge()`. Base URL: `proto://host:port` from `useAuthStore`.
Auth: `Authorization: Bearer <token>` header on every request.

## GET /backlog

**Auth**: Bearer required
**Query params**: `project?: string`
**Returns**: `{ specs: SpecItem[] }` | `null` on error
**Calls**: `useBacklogStore.fetchSpecs()`

## GET /dashboard

**Auth**: Bearer required
**Returns**: dashboard summary JSON
**Used by**: `useBridge.healthCheck()` — checks `res.ok` only

## POST /auth/login

**Auth**: None (unauthenticated)
**Body**: `{ username: string, token: string, serverUrl: string }`
**Returns**: `{ token: string, profile: TeamMember }` | `null` on error
**Calls**: `useAuthStore.login()`

## GET /auth/me

**Auth**: Bearer required
**Returns**: `{ role: 'admin' | 'user', name: string, … }`
**Used by**: router admin guard on navigation to `/admin/users`

## GET /telemetry

**Auth**: Bearer required
**Returns**: telemetry payload (SPEC-191)
**Notes**: endpoint planned; not yet live
