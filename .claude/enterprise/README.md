# Savia Enterprise — Module Layer (opt-in)

> **License:** MIT · **Status:** foundations (SE-001)
> **Spec:** `docs/propuestas/savia-enterprise/SPEC-SE-001-foundations.md`

## What this directory is

Optional extension layer for Savia Core. Everything here is MIT, opt-in, and
unidirectional: Enterprise depends on Core, Core never depends on Enterprise.

Deleting this directory must leave a fully functional Savia Core installation.
That invariant is enforced by `scripts/validate-layer-contract.sh`.

## What lives here

| Subdir | Contents |
|--------|----------|
| `agents/` | Enterprise-only agents (multi-tenant, governance, etc.) |
| `commands/` | Enterprise slash commands |
| `skills/` | Enterprise skills |
| `rules/` | Enterprise rule extensions |
| `manifest.json` | Declares which modules are active |

## Activation model

A fresh clone of Savia has Enterprise **dormant**. To activate:

1. Edit `.claude/enterprise/manifest.json`
2. Set `modules.<name>.enabled = true`
3. Core hooks detect the flag and start honoring Enterprise behavior
4. Uninstalling = set all flags to false (reversible, no data loss)

No network calls. No telemetry. No feature gates outside this directory.

## Foundational principles (inherited from Core, non-negotiable)

1. Data sovereignty — `.md` is truth
2. Vendor independence — adapters, not couplings
3. Radical honesty
4. Absolute privacy — N4 never leaves
5. Humans decide — never autonomous merge
6. Equality shield
7. Identity protection — Savia stays Savia

Any Enterprise module that violates one of these is rejected in review,
without exception, without override.

## How to contribute a module

1. Read `docs/propuestas/savia-enterprise/DEVELOPMENT-PLAN.md`
2. Pick a spec from SE-002..SE-011
3. Follow `dev-session-protocol.md` (5 phases)
4. Run `/pr-plan` before opening PR
5. PR opens as **draft** with human reviewer assigned
