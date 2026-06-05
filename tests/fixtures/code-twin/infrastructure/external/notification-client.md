---
module_id: NotificationClient
layer: infrastructure
version: "1.0.0"
last_sync: "2026-06-01T14:30:00Z"
token_budget: 310
stale_after_days: 30
depends_on: []
provides:
  - sendEmail
  - sendWebhook
status: STABLE
---
# NotificationClient — fixture-project

External HTTP client wrapping the notification provider API. All calls are
fire-and-forget; failures are logged and do NOT bubble up to the caller.

## sendEmail(to: string, template: string, vars: object): void

**HTTP**: POST https://notify.example.internal/v1/email
**Headers**: `Authorization: Bearer {NOTIFY_API_KEY}` (env var)
**Payload**: `{ to, template, variables: vars }`
**Timeout**: 3000ms
**Retry**: 1 retry on 5xx; no retry on 4xx
**Side effects**: external HTTP call; no DB writes
**Edge cases**: invalid `to` → provider returns 422; swallowed, logged at WARN

## sendWebhook(url: string, payload: object): void

**HTTP**: POST `url`
**Timeout**: 5000ms
**Retry**: none — webhook delivery is best-effort
**Side effects**: external HTTP call
