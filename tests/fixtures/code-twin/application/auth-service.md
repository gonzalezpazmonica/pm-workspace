---
module_id: AuthService
layer: application
version: 1.0.0
last_sync: 2026-06-06
token_budget: 620
depends_on:
  - UserRepository
  - TokenService
provides:
  - login
  - logout
  - refreshToken
  - validateToken
stale_after_days: 3650  # SE-191 fix: avoid temporal aging of fixture
---

# AuthService
**Layer**: application
**Source**: `src/application/auth.service.ts`

#### login(email: string, password: string): Promise<AuthResult>
**Logic**:
1. Validate email is non-empty and matches email regex pattern
2. Look up user by email in UserRepository; return INVALID_CREDENTIALS if not found
3. Compare bcrypt hash of provided password with stored password_hash
4. If mismatch, return INVALID_CREDENTIALS (do not reveal which field failed)
5. If user.disabled is true, return USER_DISABLED with 403
6. Call TokenService.generate to create JWT with sub=user.id, exp=+1h
7. Record last_login_at via UserRepository.updateLastLogin
8. Return { token, user: { id, email, role } }

**Returns**: `Promise<AuthResult>`

#### logout(token: string): Promise<void>
**Logic**:
1. Validate token signature via TokenService.verify
2. Add token jti to revocation set with TTL equal to remaining exp
3. If TokenService.verify throws, silently ignore (token already invalid)

**Returns**: `Promise<void>`

#### refreshToken(token: string): Promise<string>
**Logic**:
1. Validate token is not in revocation set
2. Call TokenService.verify; if expired but within 24h grace period, allow refresh
3. Revoke old token (add to revocation set)
4. Issue new JWT with same sub and role, exp=+1h

**Returns**: `Promise<string>`

#### validateToken(token: string): Promise<TokenPayload>
**Logic**:
1. Check revocation set for token jti; return INVALID_TOKEN if revoked
2. Call TokenService.verify; if throws, return INVALID_TOKEN
3. Return decoded payload { sub, role, exp, jti }

**Returns**: `Promise<TokenPayload>`
