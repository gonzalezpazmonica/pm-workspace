---
status: PROPOSED
---

# Savia Enterprise — Extension Points

> **Spec:** SE-001 · **Status:** foundations
> Contract that allows Enterprise modules to extend Core without modifying it.

## Principle

Enterprise extends. Enterprise does not replace. Every extension point is a
named hook or registry that Core queries at runtime. If no Enterprise module
implements it, Core falls back to its default behavior. Behavior is always
backward-compatible with a pure Core installation.

---

## EP-1: Agent Registry

**Purpose:** let Enterprise add new agents without editing `.claude/agents/`.

**Contract:** Core walks `.claude/agents/` first, then `.claude/enterprise/agents/`
if manifest flag allows. Name collisions → Enterprise wins with WARNING in log.

**Used by:** SE-002 (tenant-aware agents), SE-006 (governance agents).

---

## EP-2: Hook Registry

**Purpose:** chain Enterprise hooks after Core hooks without modifying
`.claude/settings.json` in Core.

**Contract:** a secondary settings file `.claude/enterprise/settings.json`
is loaded additively after Core. Hooks declared there run AFTER Core hooks
on the same event. Never before — safety hooks of Core always run first.

**Used by:** SE-002 (tenant-isolation-gate), SE-005 (network-egress-guard),
SE-006 (compliance-gate-ai-act).

---

## EP-3: RBAC Gate

**Purpose:** intercept commands for permission checks when multi-tenant is on.

**Contract:** `.claude/enterprise/rbac/gate.sh` is an optional PreToolUse hook
that receives command + user + tenant and returns 0 (allow) or 2 (deny with
explanation). If file absent → no-op.

**Used by:** SE-002 (multi-tenant RBAC).

---

## EP-4: Audit Sink

**Purpose:** add an additional audit stream beyond Core's `output/audit.jsonl`.

**Contract:** `.claude/enterprise/audit/sinks.d/*.sh` scripts are called on
each auditable event with a JSON payload on stdin. Scripts SHOULD be fast
(<50ms) and idempotent. Failures are logged but do not block Core.

**Used by:** SE-006 (Ed25519 signed chain), SE-009 (OTel span export).

---

## EP-5: Tenant Resolver

**Purpose:** determine the active tenant for the current session.

**Contract:** `.claude/enterprise/tenant-resolver.sh` is called once per
session. Returns the tenant slug on stdout, or empty string for single-tenant
mode. If file absent → Core runs in single-tenant mode by default.

**Used by:** SE-002 (all tenant operations).

---

## EP-6: Compliance Validator

**Purpose:** plug optional validators (AI Act, NIS2, DORA) into `/pr-plan`.

**Contract:** `.claude/enterprise/compliance/validators.d/*.sh` scripts are
invoked during the `/pr-plan` G9 gate. Each script prints a JSON verdict
`{ok: bool, reason: str}`. A single failing validator blocks the plan.

**Used by:** SE-006 (AI Act, NIS2, DORA gates).

---

## Invariants enforced by SE-001

1. **Unidirectional import**: no file under `.claude/{agents,commands,skills,rules,hooks}/`
   may reference `.claude/enterprise/`. Verified by `validate-layer-contract.sh`.
2. **Opt-in by default**: `manifest.json` ships with every module disabled.
3. **Reversible**: disabling all modules returns the system to pure Core.
4. **Silent fallback**: missing extension point files never error, they no-op.
5. **Safety hooks unaffected**: Core safety hooks (credentials, force-push,
   sovereignty) always run first and cannot be overridden by Enterprise.

---

## Anti-patterns (forbidden)

- Importing `.claude/enterprise/*` from Core (breaks invariant #1)
- Modifying Core files to add Enterprise behavior (use extension points)
- Extension points that bypass safety hooks (breaks invariant #5)
- Extension points that require Enterprise to be active (breaks invariant #2)
- Network calls from extension points without explicit opt-in (breaks sovereignty)

---

## Testing each extension point

Each extension point has a BATS test in `tests/enterprise/extension-points.bats`
that verifies:

- Core works with Enterprise directory deleted
- Core works with `manifest.json` all-disabled
- Enabling one module affects only that module's contract
- Disabling a module restores Core behavior exactly
