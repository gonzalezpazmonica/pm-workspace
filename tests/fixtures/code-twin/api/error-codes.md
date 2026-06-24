---
module_id: api-error-codes
layer: api
version: "1.0.0"
last_sync: "2026-06-23T07:37:07Z"
token_budget: 200
stale_after_days: 30
depends_on: []
provides:
  - VALIDATION_ERROR
  - NOT_FOUND
  - UNAUTHORIZED
  - FORBIDDEN
  - INVALID_STATE
status: STABLE
---
# API Error Codes — fixture-project

All error responses follow `{ error: { code, status, message } }`.

| code | status | when |
|------|--------|------|
| VALIDATION_ERROR | 400 | input fails schema or business validation |
| UNAUTHORIZED | 401 | missing or invalid bearer token |
| FORBIDDEN | 403 | valid token but insufficient role |
| NOT_FOUND | 404 | resource does not exist |
| INVALID_STATE | 422 | operation not allowed in current state |
| INTERNAL_ERROR | 500 | unhandled exception — never exposes stack trace |
