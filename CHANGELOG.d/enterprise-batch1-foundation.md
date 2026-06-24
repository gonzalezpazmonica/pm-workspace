# Enterprise Batch 1 — Foundation

**Date:** 2026-06-24
**Specs:** SE-002 (Extension Points), SPEC-SE-002 (Multi-Tenant), SPEC-SE-005 (Sovereign), SPEC-SE-010 (Migration Path)

## Scripts created

### SE-002 — Extension Points

| Script | Purpose |
|---|---|
| `scripts/enterprise/tenant-create.sh` | Creates tenant directory structure with rbac.yaml (3 roles) |
| `scripts/enterprise/rbac-check.sh` | Checks if a user has permission for a command in a tenant |

### SPEC-SE-002 — Multi-Tenant

| Script | Purpose |
|---|---|
| `scripts/enterprise/tenant-activate.sh` | Activates multi-tenant mode; creates tenants/, registers hooks |
| `scripts/enterprise/rbac-bulk-assign.sh` | Bulk-assigns roles from CSV (user_slug,tenant_slug,role) |

### SPEC-SE-005 — Sovereign Deployment

| Script | Purpose |
|---|---|
| `scripts/enterprise/sovereign-activate.sh` | Configures sovereign/air-gap/hybrid mode; creates deployment.yaml |
| `scripts/enterprise/deployment-status.sh` | Reports current deployment mode (mode, llm_provider, egress_allowed) |

### SPEC-SE-010 — Migration Path

| Script | Purpose |
|---|---|
| `scripts/enterprise/enterprise-migrate.sh` | Unified migration CLI: check/enable/disable/status subcommands |
| `scripts/enterprise/rollback-module.sh` | Reverts a module to enabled=false; removes its hooks from settings.json |
| `scripts/lib/enterprise-migrate-helpers.py` | Python backend for enterprise-migrate.sh |

## Documentation

- `docs/rules/domain/enterprise-sovereign-deployment.md` — Activation guide, deployment modes, network guard, hardware reference, troubleshooting, rollback

## Tests

| Suite | Tests | Result |
|---|---|---|
| `tests/enterprise/test-se-002-foundation.bats` | 8 | 8/8 pass |
| `tests/enterprise/test-se-002-multitenant.bats` | 8 | 8/8 pass |
| `tests/enterprise/test-se-005-sovereign.bats` | 9 | 9/9 pass |
| `tests/enterprise/test-se-010-migration.bats` | 10 | 10/10 pass |
| **Total** | **35** | **35/35** |

## Spec status

All 4 specs flipped: PROPOSED → IMPLEMENTED
