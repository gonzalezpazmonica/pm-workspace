# Multi-Tenant & RBAC (SE-002)

> Enterprise module. Requires `multi-tenant: { enabled: true }` in manifest.

## Tenant model

A tenant is a directory under `tenants/{slug}/` with isolated projects,
agent memory, secrets, and RBAC configuration. Isolation is enforced by
hooks, not by filesystem permissions.

## Resolution order

`tenant-resolver.sh` resolves the active tenant:
1. `$SAVIA_TENANT` environment variable (explicit)
2. Current working directory under `tenants/{slug}/` (implicit)
3. User profile `identity.md` with `tenant: <slug>` (persistent)
4. Empty = single-tenant mode (Core untouched)

## Isolation rules

- **Read/Write**: `tenant-isolation-gate.sh` blocks access to `tenants/<other>/`
- **Agent memory**: per-tenant under `tenants/{slug}/agent-memory/`
- **Memory recall**: cannot cross tenant boundaries
- **Audit**: every entry includes `tenant_id`

## RBAC

`tenants/{slug}/rbac.yaml` declares roles with command patterns:

```yaml
roles:
  reader:
    commands: [sprint-status, help, memory-recall]
  developer:
    inherits: reader
    commands: [spec-*, pbi-*, dev-session-*]
  admin:
    inherits: developer
    commands: [tenant-*, rbac-*, backup-*]
    gates: [confirm_destructive]
```

`scripts/rbac-manager.sh` manages grants: `grant`, `revoke`, `list`, `check`.

## Savia Shield integration

`data-sovereignty-gate.sh` treats `tenants/` paths as N4 (private).
Content in tenant dirs is never scanned for public-repo leakage.

## Feature flag

Disabled: `multi-tenant.enabled: false` in manifest → all hooks are no-op,
Core operates in single-tenant mode as before SE-002.

## Extension point used

EP-5: Tenant Resolver (from SE-001 `extension-points.md`).
