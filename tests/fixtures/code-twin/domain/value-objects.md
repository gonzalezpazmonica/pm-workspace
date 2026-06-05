---
module_id: value-objects
layer: domain
version: "1.0.0"
last_sync: "2026-06-01T14:30:00Z"
token_budget: 220
stale_after_days: 60
depends_on: []
provides:
  - Email
  - Money
status: STABLE
---
# Value Objects — fixture-project

## Email

**Format**: RFC 5322 (e.g. `user@example.com`)
**Validation**: regex `^[^\s@]+@[^\s@]+\.[^\s@]+$`; max 320 chars; case-insensitive equality
**Examples**: `alice@test.com`, `bob+tag@company.org`
**Invalid**: `user@`, `@domain.com`, plain string without `@`
**Immutability**: value set at creation, never mutated

## Money

**Format**: `{ amount: decimal, currency: string }`
**Validation**: `amount ≥ 0`; `currency` is ISO 4217 (3 uppercase letters)
**Examples**: `{amount: 49.99, currency: "EUR"}`, `{amount: 0, currency: "USD"}`
**Arithmetic**: operate in integer cents (multiply by 100) to avoid float errors; never `Math.round` mid-calculation
