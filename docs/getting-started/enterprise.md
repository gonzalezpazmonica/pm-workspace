---
title: Getting Started — Enterprise
order: 2
category: getting-started
---

# Getting Started with Savia Enterprise

Savia Enterprise extends Core with opt-in modules for multi-tenant
isolation, compliance automation, sovereign deployment, and consultancy
lifecycle management. All modules are MIT-licensed and reversible.

## Prerequisites

- Savia Core working (see [community.md](community.md))
- `.claude/enterprise/manifest.json` present (included in the repo)

## Check status

```bash
bash scripts/savia-enterprise.sh status
# → "Mode: Community (all modules disabled)"
```

## Enable a module

```bash
bash scripts/savia-enterprise.sh modules          # list all 16
bash scripts/savia-enterprise.sh enable multi-tenant
bash scripts/savia-enterprise.sh enable code-review-court
bash scripts/savia-enterprise.sh status
# → "Mode: Enterprise (2 active modules)"
```

## Available modules

| Module | Spec | What it adds |
|--------|------|-------------|
| multi-tenant | SE-002 | Tenant isolation, RBAC per tenant |
| code-review-court | SE-021 | 5-judge review tribunal |
| release-orchestration | SE-014 | Release-as-Code with compliance profiles |
| project-lifecycle | SE-015..020 | Full consultancy lifecycle |
| resource-bench | SE-022 | Skills matching, bench optimization |
| compliance-evidence | SE-026 | Automated audit trail (ISO 9001, DORA) |
| ... | | See `savia-enterprise.sh modules` for full list |

## Disable / uninstall

```bash
bash scripts/savia-enterprise.sh disable multi-tenant  # one module
bash scripts/savia-enterprise.sh uninstall              # all modules → Community
```

Uninstall is clean: Core returns to exactly the same state as before.
Your project data is never deleted.

## Architecture

```
Core (.claude/agents, commands, skills, rules, hooks)
  ↑ never imports from ↓
Enterprise (.claude/enterprise/agents, commands, skills, rules, hooks)
  ↑ extends Core via 6 extension points (SE-001)
```

See [docs/enterprise/overview.md](../enterprise/overview.md) for the
full architecture and module dependency graph.
