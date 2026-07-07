---
module_id: business-rules
layer: domain
version: "1.0.0"
last_sync: "2026-07-07T00:00:00Z"
token_budget: 180
stale_after_days: 30
depends_on:
  - domain-entities
provides:
  - BR-001
  - BR-002
  - BR-003
status: STABLE
---
# Business Rules — fixture-project

## BR-001: User account deactivation
- A disabled user cannot authenticate (check `disabled` before password comparison)
- Only admin role can disable users
- A user cannot disable themselves

## BR-002: Order lifecycle
- Orders in `completed` or `cancelled` are immutable — no field updates allowed
- `total` must be ≥ 0 at all times, including after any discount
- `userId` must reference an existing, non-disabled User

## BR-003: Email uniqueness
- Email must be unique across all users (case-insensitive comparison at write time)
- Email cannot be changed post-registration
