---
id: "phase3-per-user-tokens"
title: "Per-User Authentication Tokens"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# Per-User Authentication Tokens

## Objetivo

Replace the single shared Bridge token with individual per-user tokens. Each user gets their own token stored in their profile directory. The Bridge validates tokens against the user database, not a single file.

## Current State

- Single token in `~/.savia/bridge/auth_token` (shared by all users)
- Bridge checks `Authorization: Bearer {token}` against this single token
- No way to identify WHO is making a request
- No way to revoke access for a single user

## Target State

```
~/.savia/bridge/
├── auth_token          ← Master admin token (kept for backwards compat)
└── users/
    ├── monica/
    │   ├── token       ← Individual token (43 chars, 0600 perms)
    │   ├── profile.json ← { slug, name, role, created, lastLogin }
    │   └── sessions/
    ├── alice/
    │   ├── token
    │   ├── profile.json
    │   └── sessions/
    └── ...
```

## Requisitos Funcionales

### RF-01: Token Generation

- On user creation, generate a unique 43-char token (base64url, cryptographically random)
- Store in `~/.savia/bridge/users/{slug}/token` with `0600` permissions
- Token is independent of master token

### RF-02: Token Validation

- Bridge checks incoming `Bearer {token}` against ALL user tokens
- If match found → request authenticated as that user
- If matches master token → authenticated as admin (backwards compat)
- If no match → 401 Unauthorized
- User slug injected into request context for audit trail

### RF-03: Token Lifecycle

- `/auth/register` creates user + generates token (returns token once)
- `PUT /users/{slug}/rotate-token` regenerates token (admin or self only)
- `DELETE /users/{slug}/token` revokes access (admin only)
- Revoking master token is blocked (safety)

### RF-04: Migration

- On Bridge startup, if `users/` dir doesn't exist, create it
- If existing profiles exist in `.claude/profiles/users/`, create user entries
- Master token remains valid as admin fallback

### RF-05: Login Flow Change

- savia-web login sends `@handle` + token
- Bridge validates token belongs to that user (not just any valid token)
- If token valid but wrong user → 403 Forbidden

## Criterios de Aceptacion

- [ ] Each user has their own unique token
- [ ] Token stored in user profile directory with 0600 perms
- [ ] Bridge identifies user from token (not just authenticates)
- [ ] Master token still works as admin fallback
- [ ] Revoking one user's token doesn't affect others
- [ ] Token rotation works without service restart
- [ ] Login rejects valid token used with wrong @handle
