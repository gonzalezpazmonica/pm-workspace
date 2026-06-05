---
module_id: AuthService
layer: application
version: "1.0.0"
last_sync: "2026-06-01T14:30:00Z"
token_budget: 580
stale_after_days: 14
depends_on:
  - UserRepository
  - JwtService
provides:
  - login
  - logout
  - refresh
  - validateToken
status: STABLE
---
# AuthService

## Logic summary
Handles authentication flows.

#### login(email: string, password: string): LoginResult

**Logic**:
1. UserRepository.findByEmail(email) → null → THROW 401 code=INVALID_CREDENTIALS
2. bcrypt.compare(password, user.passwordHash) → false → THROW 401
3. JwtService.sign({sub: user.id, roles: user.roles}) → token: string
4. UserRepository.updateLastLogin(user.id, now) → side-effect DB WRITE

**Side effects**: DB WRITE users.last_login_at

**Edge cases**: user.disabled=true → THROW 403 USER_DISABLED
