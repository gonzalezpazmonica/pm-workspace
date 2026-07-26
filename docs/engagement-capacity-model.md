---
name: engagement-capacity-model
description: "Per-engagement capacity model — what the contract justifies, not RBAC on person"
auto_load: false
supersedes: docs/rules/domain/rbac-model.md
supersedes_reason: "SE-271 moves from person-based RBAC to engagement-based capacity enforcement"
context_tier: L1
token_budget: 1000
---

# Engagement Capacity Model

> SE-271 S4 — Capacities per engagement, deny-by-default.
> Supersedes `docs/rules/domain/rbac-model.md` (archived at
> `docs/rules/domain/archived/rbac-model.md`).

## Not RBAC on person, but capacities per engagement

RBAC grants permissions to a **person** across the workspace.
Engagement capacity grants capacities to a **contract** for a specific
client engagement. The question is not "what is Alice's role?" but
"what does the contract with Acme justify?"

## Capacity model

Each engagement declares allowed capacities in its YAML file:

```yaml
engagement:
  id: "acme-q3-2026"
  client: "acme-corp"
  body: "acme-corp-division"
  wall: "wall-acme"            # data partition
  status: active
  start: "2026-07-01"
  end: "2026-09-30"
  scope:
    domains: [code, docs, testing, analysis]
    tools: [bash, python, git, read, write, edit]
    actions: [spec-generate, code-audit, report-executive]
```

## Enforcement points

### plugin tool.execute

`scripts/engagement-capacity-check.sh` gates every tool invocation when
an active engagement context exists. Checks:

- **Tool**: is this tool type within engagement scope?
- **Domain**: is this domain within engagement scope?
- **Action**: is this action within engagement scope?

Deny-by-default: undeclared capacity → denied citing the engagement.

### hook dispatcher

`.opencode/hooks/` PostToolUse hook validates that output does not cross
wall boundaries. Wall integrity is per-engagement, not per-user.

## Operator mode (no engagement)

Without an active engagement context, the operator has **unrestricted**
capacity. This is the default for pm-workspace maintenance, Savia
development, and any work not bound to a client contract.

## Wall integrity

Each engagement has a `wall` field that partitions data. No tool
execution may move data from one wall to another. Cross-wall access
requires explicit operator override with audit trail.

## Migration from RBAC

| RBAC concept | Engagement capacity equivalent |
|---|---|
| `role: Admin` | Operator (no engagement) |
| `role: PM` | Engagement with `scope.domains: [analysis, docs]` |
| `role: Contributor` | Engagement with `scope.domains: [code, testing]` |
| `role: Viewer` | Engagement with `scope.actions: [report-*]` but no write tools |
| Scope per-project | Engagement walls |

## See also

- `scripts/engagement-capacity-check.sh` — Runtime enforcement
- `scripts/corporate-attest.sh` — Fleet-level attestation (SE-271 S5)
- `scripts/corporate-no-write-assert.sh` — No corporate write path assertion
