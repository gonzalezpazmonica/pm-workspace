# Spec: Login — First-time Connection & User Identification

## Metadatos
- project: savia-web
- feature: login
- status: pending
- depends: FR-11 (ConnectionWizard)

## Objective

Replace the auto-connect wizard with a proper login screen that collects server
URL, username (@handle), and access token. Persist credentials in a cookie.
Load the user's team profile. If the user doesn't exist, guide them through
registration.

## User Flow

### 1. First Visit (no cookie)
1. Full-screen login form with 3 fields:
   - **Server URL** (e.g. `http://localhost:8922`) — placeholder with default
   - **Username** (must start with `@`, e.g. `@monica`) — validated on input
   - **Access token** — the Bridge bearer token from `~/.savia/bridge/auth_token`
2. User clicks "Connect"
3. App calls `GET {serverUrl}/health` to verify the bridge is reachable
4. App calls `GET {serverUrl}/team` with `Authorization: Bearer {token}`
5. Search `team.members[]` for member where `slug === username` (without @)
6. **If found**: load profile (name, role, email, company) → go to dashboard
7. **If not found**: show registration wizard (step 2 below)

### 2. Registration Wizard (user not in team)
Modal form with fields:
- **Name** (required)
- **Role** (dropdown: PM, Tech Lead, Developer, QA, Product Owner, CEO/CTO)
- **Email** (optional)
Only shown when @handle has no matching profile in `/team`.
On submit: `PUT {serverUrl}/team` with `action: "add"`, `slug`, `identity`.
After success: reload team, continue to dashboard.

### 3. Return Visit (cookie exists)
1. Read cookie `savia_session` (JSON: `{serverUrl, username, token}`)
2. Auto-connect using stored values
3. If connection fails (bridge down), show login form pre-filled with stored values

### 4. Logout
- TopBar shows: `Connected · {profileName}` + logout button
- Logout clears the cookie and reloads the page → back to login form

## Persistence

Cookie name: `savia_session`
Value: JSON `{ "serverUrl": "...", "username": "@...", "token": "..." }`
Expiry: none (persistent until explicit logout)
Path: `/`

## Bridge API Used

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | No | Verify bridge reachable |
| GET | `/team` | Yes | List team members with profiles |
| PUT | `/team` | Yes | Register new team member |
| GET | `/dashboard` | Yes | Load dashboard after login |

## Acceptance Criteria

**Given** user visits for the first time (no cookie),
**When** the page loads,
**Then** a full-screen login form shows Server URL, @username, and token fields.

**Given** user enters valid server URL, @username matching a team member, and valid token,
**When** user clicks Connect,
**Then** profile loads, cookie is set, and dashboard appears with name in TopBar.

**Given** user enters @username that doesn't exist in team,
**When** Connect succeeds but no profile matches,
**Then** a registration form appears asking for name, role, and email.

**Given** user has a valid cookie from a previous session,
**When** the page loads,
**Then** auto-connect occurs and dashboard appears without showing login.

**Given** user clicks Logout in the TopBar,
**When** the action completes,
**Then** cookie is cleared and login form reappears.

## Components Affected

| Component | Change |
|---|---|
| `LoginPage.vue` | **New** — full-screen login form |
| `RegisterWizard.vue` | **New** — new team member registration |
| `ConnectionWizard.vue` | **Remove** — replaced by LoginPage |
| `MainLayout.vue` | Show LoginPage instead of ConnectionWizard |
| `AppTopBar.vue` | Add profile name + logout button |
| `stores/auth.ts` | Cookie persistence, profile data, logout |
| `types/bridge.ts` | Add `TeamMember` type if missing |

## File Limit
All files ≤ 150 lines.
