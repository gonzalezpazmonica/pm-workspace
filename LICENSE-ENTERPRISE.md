# Savia Enterprise — License

**License:** MIT (identical to Savia Core)
**Status:** Permanent. Non-revocable. Not subject to dual-licensing.

## Statement

Every file under `.claude/enterprise/` — including all current and future
agents, commands, skills, rules, and manifests — is released under the
MIT License, the same terms as Savia Core (see `LICENSE` at repo root).

There is no "Enterprise Edition" in the proprietary sense. There is no
paid tier of the code. There is no feature gated behind a paywall. The
Enterprise layer is a set of optional modules that activate additional
capabilities (multi-tenant governance, sovereign audits, MCP catalogs,
adapters). All of it is free software, forever.

## Why this is non-negotiable

Savia Enterprise serves organizations that need data sovereignty,
vendor independence, and the ability to inspect every line of code that
runs against their data. A proprietary license — even a partial one —
would contradict the 7 foundational principles that define Savia:

1. Data sovereignty: `.md` is truth
2. Vendor independence
3. Radical honesty
4. Absolute privacy
5. The human decides
6. Equality shield
7. Identity protection

See `docs/rules/domain/savia-foundational-principles.md` for the
full text. These principles predate the Enterprise layer and constrain
every decision about how it is built and licensed.

## Rejected licensing models

The following models were evaluated and formally rejected. Each one is
listed with the principle it violates, so future contributors understand
why reopening the debate is not productive.

### 1. Open Core + Enterprise commercial

**Pattern:** Core is open source, Enterprise features are closed and paid.

**Violates Principle 2 (vendor independence).** Open Core creates a
structural incentive to move the most valuable features into the closed
half, because that is where revenue lives. Over time, the open core
becomes a demo. Customers who bought the closed tier are locked in;
customers who didn't are locked out. Either way, independence dies.

### 2. BSL (Business Source License)

**Pattern:** Source-available now, converts to open source after N years.

**Violates Principle 2 (vendor independence).** BSL is time-limited
vendor lock-in dressed up as open source. During the lock-in window,
users cannot legally self-host for competing purposes, cannot fork,
and cannot eliminate the vendor. The market has learned this pattern
and punishes it: every major BSL re-license in the last five years
triggered a fork.

### 3. AGPL (Affero GPL)

**Pattern:** Strong copyleft; anyone running a modified version over
a network must publish their changes.

**Violates Principle 5 (the human decides) and creates practical
lock-out in regulated sectors.** Savia Enterprise targets banks,
healthcare providers, and legal firms, all of which routinely modify
internal configuration for compliance reasons. AGPL would force them
to either publish those modifications (impossible under their own
regulatory constraints) or stop using Savia. The human decides how
their derivatives are shared, not the license.

### 4. SaaS hosted

**Pattern:** Savia runs as a service operated by the maintainers;
customer data flows through maintainer-operated infrastructure.

**Violates Principles 1 and 4 (data sovereignty and absolute
privacy).** The moment customer data touches a machine that is not
the customer's, the sovereignty guarantee is broken. No operational
promise replaces the architectural guarantee of "data never leaves
your disk".

### 5. Pay-per-agent / pay-per-seat

**Pattern:** Charge based on the number of agents, users, or tasks.

**Violates Principle 7 (identity protection) and Principle 2.** This
model creates a direct incentive to cap agent capabilities in Core
so the paid tier looks more valuable. Every feature added to Core
would be evaluated against "does this reduce upsell opportunity?"
That is incompatible with Savia staying Savia.

## What CAN be sold

Services. See `docs/support-offering.md` for the six categories of
services that are monetizable without touching the code:

1. Professional support with SLA
2. Implementation and migration consulting
3. Certified training
4. Custom spec development
5. Sovereignty audits
6. Hardware reference integrations

The code stays MIT. The services are commercial. This is the only
split that preserves the 7 principles while leaving room for the
project to be economically sustainable.

## Forking and naming

Forks are permitted and encouraged, under the terms of the MIT
License. See `TRADEMARK.md` at the repo root for the one constraint:
the name "Savia" is reserved for the upstream project. Forks must
rename.

## Changes to this document

This document can be edited to improve clarity, fix typos, or add
newly rejected models. It **cannot** be edited to introduce a
proprietary tier, a dual license, or any constraint that would
re-enable one of the five rejected models above. Such a change would
violate the foundational principles and is out of scope for any
contributor, maintainer, or funder.
