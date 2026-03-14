# Spec: Multi-User Session Architecture

## Metadatos
- project: savia-bridge, savia-web, savia-mobile
- feature: multi-user-sessions
- status: implementing
- depends: login.spec.md

## Objective

Enable multiple users to chat independently via savia-bridge without
blocking each other or the host's terminal Claude session. Sessions
persist across app restarts and are shared between web and mobile.

## Architecture

### Per-User Directory (`~/.savia/bridge/users/{slug}/`)
```
users/
├── alice/
│   ├── token              # Per-user bearer token (43 chars, 0600)
│   ├── sessions.json      # ["uuid1", "uuid2", ...] owned sessions
│   └── workdirs/           # Isolated Claude CLI working directories
│       └── {12-char-id}/   # One per active session
└── bob/
    ├── token
    ├── sessions.json
    └── workdirs/
```

### Two-Tier Authentication
| Token type | Stored in | Can do |
|---|---|---|
| Master | `~/.savia/bridge/auth_token` | Everything + register users |
| Per-user | `~/.savia/bridge/users/{slug}/token` | Own sessions only |

### Session Isolation
Each Claude CLI process spawned by the bridge runs in an isolated `cwd`:
- `cwd = ~/.savia/bridge/users/{slug}/workdirs/{session-short-id}/`
- `--add-dir ~/claude` gives read/write access to the real workspace
- No lock contention with the host terminal's interactive Claude session

### Session Sharing (Web + Mobile)
Same `username` slug on both apps → same user dir → same sessions list.
The bridge converts non-UUID session IDs to deterministic UUIDs via
`uuid5(NAMESPACE_DNS, "savia.{session_id}")`.

## Bridge API

### POST /auth/register (master token required)
Request: `{"username": "alice"}`
Response: `{"user_token": "...", "username": "alice"}`
- Creates user dir if needed, generates token, returns it
- Idempotent: calling again returns existing token

### POST /chat (user token)
- Session auto-registered to user on first use
- User can only access own sessions (403 otherwise)

### GET /sessions (user token)
- Returns only sessions owned by the authenticated user

### GET /sessions (master token)
- Returns all sessions across all users

## Client Flows

### Web (savia-web)
1. Login form collects: serverUrl, @username, master token
2. After /team check, calls POST /auth/register with master token
3. Exchanges master token for per-user token, stores in cookie
4. Chat sessions derived from username: `{slug}-default`
5. Subsequent requests use per-user token

### Mobile (savia-mobile)
1. BridgeSetupDialog collects: host, port, username, master token
2. After health check, calls POST /auth/register with master token
3. Stores per-user token in SecureStorage (replaces master)
4. Conversation IDs (UUIDs from Room DB) serve as session IDs
5. Subsequent requests use per-user token

## Backward Compatibility
- Master token continues to work for all endpoints (admin access)
- Old clients without username get admin-level access (no scoping)
- Existing global sessions remain accessible via master token

## Acceptance Criteria

**Given** two users (alice, bob) each with their own token,
**When** alice sends a chat message,
**Then** bob's sessions are unaffected and alice cannot see bob's sessions.

**Given** a user is chatting via savia-web,
**When** the host is using Claude interactively in the terminal,
**Then** the web chat responds without blocking (isolated workdir).

**Given** a user logs in on savia-web and savia-mobile with same @username,
**When** they create a session on mobile,
**Then** the session appears in GET /sessions on web (shared).

## File Limit
All files ≤ 150 lines.
