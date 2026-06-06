---
module_id: FrontendStores
layer: frontend
version: "1.0.0"
last_sync: "2026-06-06T10:00:00Z"
token_budget: 460
stale_after_days: 14
depends_on:
  - FrontendComposables
  - DomainEntities
provides:
  - useAuthStore
  - useBacklogStore
status: STABLE
---
# Frontend Stores — savia-web

## useAuthStore

**State**: `serverUrl: string`, `username: string`, `token: string`, `connected: boolean`, `profile: TeamMember | null`, `role: 'admin' | 'user'`
**Computed**: `profileName`, `isLoggedIn` (connected && !!token && !!username), `isAdmin` (role === 'admin'), `hasCookie`
**Cookies**: `savia_session` (session cookie: serverUrl+username+token), `savia_connection` (persistent 1yr: serverUrl+token)
**Methods**:
- `login(url, user, tok, member)` — sets state, writes `savia_session` cookie
- `logout()` — clears state, clears `savia_session` cookie
**Persistence**: cookie-based; restored from `savia_session` or `savia_connection` on init

## useBacklogStore

**State**: `specs: SpecItem[]`, `loading: boolean`, `filters: BacklogFilters`, `viewMode: 'tree' | 'kanban'`
**Computed**: `filteredSpecs` — applies `filters` to `specs`; `totalItems` — flattened count
**Methods**:
- `fetchSpecs(project?)` — calls `GET /backlog?project=...`, sets `specs`, handles `loading`
- `setFilters(partial)` — merges partial filters, persists to localStorage
- `setViewMode(mode)` — persists to localStorage
**Persistence**: `savia:backlog:filters` and `savia:backlog:viewMode` in localStorage
**Side effects**: `watch(project, fetchSpecs)` — auto-refetch on project change
