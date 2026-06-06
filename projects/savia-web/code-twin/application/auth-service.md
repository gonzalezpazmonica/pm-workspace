---
module_id: AuthService
layer: application
version: "1.0.0"
last_sync: "2026-06-06T10:00:00Z"
token_budget: 420
stale_after_days: 14
depends_on:
  - FrontendStores
  - ApiRoutes
provides:
  - login
  - logout
  - getProfile
status: STABLE
---
# AuthService — savia-web

Orchestrates authentication flow: credential submission, token storage, profile load.
Implemented as methods on `useAuthStore` backed by `useBridge`.

#### login(serverUrl, username, token)

**Args**: `serverUrl: string`, `username: string`, `token: string`
**Returns**: `{ success: boolean, profile: TeamMember | null, role: string }`

**Logic**:
1. Validate `serverUrl`, `username`, `token` are non-empty strings; return `INVALID_CREDENTIALS` if any missing
2. Call `GET /auth/me` with provided token → `{ role, name, email, … }`
3. If response is null or non-ok → return `INVALID_CREDENTIALS`
4. Set `useAuthStore.login(serverUrl, username, token, profile)`
5. Set `useAuthStore.role` from `/auth/me` response
6. Write `savia_session` cookie via `writeCookie(serverUrl, username, token)`
7. Return `{ success: true, profile, role }`

**Side effects**:
- Writes `savia_session` cookie (expires with session)
- Sets `useAuthStore.connected = true`

**Edge cases**:
- Empty token → INVALID_CREDENTIALS
- Server unreachable → useBridge returns null → INVALID_CREDENTIALS
- role not in response → default to `'user'`

#### logout()

**Logic**:
1. Clear `useAuthStore` state (token, username, profile, connected=false)
2. Clear `savia_session` cookie via `clearCookie()`
3. Redirect to `/`

#### getProfile()

**Logic**:
1. If `useAuthStore.connected && token` → call `GET /auth/me`
2. Update `useAuthStore.profile` and `role` from response
3. Return profile or null
