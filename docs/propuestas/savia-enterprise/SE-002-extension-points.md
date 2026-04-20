---
id: SE-002
status: PROPOSED
---

# SE-002 — Extension Points Implementation

> **Spec:** SE-002 · **Status:** implemented
> Concrete implementation of EP-3 (RBAC Gate) and EP-5 (Tenant Resolver)
> declared in `extension-points.md` (SE-001).

## EP-5 — Tenant Resolver

**File:** `.claude/enterprise/hooks/tenant-resolver.sh`

**Behaviour:** prints the active tenant slug to stdout, or empty string for
single-tenant mode. Designed to be sourced (exposes `tenant_resolve()`) or
run standalone.

**Resolution order:**

1. `$SAVIA_TENANT` environment variable
2. Current working directory matches `tenants/<slug>/...`
3. Active user profile — reads `active_slug` from
   `.claude/profiles/active-user.md`, then looks up
   `tenant:` in `.claude/profiles/users/<slug>/identity.md`
4. Fallback → empty string (Core runs pure single-tenant mode)

**Safety:** the resolver never reads outside `$CLAUDE_PROJECT_DIR`, does not
mutate state, and never blocks — absence of any source simply yields empty.

**Core fallback guarantee:** if the file is missing, Core code that checks
for a tenant sees an empty slug and operates exactly as pre-SE-002.

## EP-3 — RBAC Gate (tenant-isolation-gate)

**File:** `.claude/enterprise/hooks/tenant-isolation-gate.sh`

**Behaviour:** a `PreToolUse` hook matched against `Edit|Write|Read`. Blocks
(exit 2) any attempt to touch `tenants/<other-slug>/...` when the active
tenant is `<X>`. Allows access to:

- `.claude/`, `scripts/`, `docs/`, `tests/`, `output/` (Core allowlist)
- `tenants/<active>/...` (own tenant)

**Gate conditions — all must be true for the hook to enforce:**

- `.claude/enterprise/manifest.json` exists
- `modules["multi-tenant"].enabled == true`
- An active tenant is resolvable via EP-5

If any of those is false, the hook is a silent no-op with exit 0 and Core
keeps working untouched.

**Audit log:** every decision (ALLOW or BLOCK) is appended as a JSON line
to `output/tenant-audit.jsonl` with fields:

```json
{"ts":"2026-04-11T17:11:07Z","tenant_id":"tenant-a","path":"tenants/tenant-b/x.md","verdict":"BLOCK","reason":"cross-tenant"}
```

**Reasons:** `core-dir`, `own-tenant`, `tenants-root`, `non-tenant`, `cross-tenant`.

**Graceful input handling:**

- Empty stdin → exit 0
- Malformed JSON → exit 0 (fail-open for Core resilience; Core still owns
  its own hooks for destructive actions)
- Missing `file_path` in payload → exit 0

## RBAC Backend

**Command:** `/rbac-manager` (`.claude/enterprise/commands/rbac-manager.md`)

**Script:** `scripts/rbac-manager.sh`

Subcommands `grant`, `revoke`, `list`, `check`. Persists to
`tenants/<slug>/rbac.yaml` with atomic writes (temp + `mv`). Role
inheritance is resolved recursively; wildcard command patterns
(`spec-*`, `tenant-*`) use shell glob matching.

## Test Coverage

- `tests/test-tenant-isolation.bats` — 21 tests (resolver + gate)
- `tests/test-rbac-manager.bats` — 16 tests (grant/revoke/list/check + edges)

Both files SPEC-055 certified (≥80 audit score).

## Layer Contract

Enterprise hooks may source helpers from `.claude/hooks/lib/` and invoke
`scripts/`. Core MUST NOT reference anything under `.claude/enterprise/`.
Enforced by `scripts/validate-layer-contract.sh`.

## Wiring

Not wired into `.claude/settings.json` as an always-on hook. Activation is
gated by `manifest.json → multi-tenant.enabled`. When the module is asleep,
Core runs untouched — the spec's core promise.
