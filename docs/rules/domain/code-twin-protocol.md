---
context_tier: L2
token_budget: 600
spec: SPEC-190
status: IMPLEMENTED
---

# Code Twin Protocol — Application Code Twin (ACT)

> Canonical doc for SPEC-190. Source of truth for CTF format and usage rules.
> Related: `docs/propuestas/SPEC-190-application-code-twin.md`

## What is a CTF?

A **Code Twin File (CTF)** is a Markdown document that describes the behaviour
of one application module (service, repository, entity, route group, etc.)
without the full source code. CTFs are stored in `projects/{slug}/code-twin/`.

A collection of CTFs for a project is called an **Application Code Twin (ACT)**.

## CTF Format

Every CTF **must** have YAML frontmatter with exactly these 8 fields:

```yaml
---
module_id: AuthService          # Unique identifier in the twin
layer: application              # domain|application|infrastructure|api|frontend|cross-cutting
version: 1.0.0                  # Semantic version of the module in real code
last_sync: 2026-06-24           # Last sync date with source code (ISO 8601)
token_budget: 580               # Approximate token count of this CTF (≤800)
depends_on:                     # module_ids this CTF depends on
  - UserRepository
provides:                       # Public functions/methods exposed
  - login
  - logout
stale_after_days: 7             # Days before the CTF is considered stale
---
```

**Valid layers**: `domain`, `application`, `infrastructure`, `api`,
`frontend`, `cross-cutting`. Any other value is rejected by the linter.

**Token budget**: ≤600 normal, ≤800 with explicit exception. The linter
rejects CTFs with `token_budget > 800`.

**Status field** (optional): `STABLE` (default) or `DRAFT`.
- `DRAFT` CTFs are rejected by the linter — they are scaffolded stubs pending review.
- Set `status: STABLE` only after a human has verified the content.

## CTI (Code Twin Index)

`code-twin/index.md` is the master index. It is **always loaded first**
by the `code-twin-agent`. Its token cost must be ≤ 300.

Required frontmatter: `total_modules`, `total_token_cost`.
Required table columns: `module_id`, `layer`, `path`, `provides`, `tokens`.

## When to Use ACT vs Real Code

| Scenario | Use ACT | Use Real Code |
|---|---|---|
| Spec authoring / planning |  | — |
| Understanding architecture |  | — |
| Impact analysis |  | — |
| Production debugging | — |  |
| Security audit | — |  |
| CTF is stale | — |  |
| Implementing exact logic | — |  |

**Rule**: ACT is a map, not the territory. When the map and territory disagree,
the territory (source code) wins.

## Staleness

A CTF becomes **stale** when `today ≥ last_sync + stale_after_days`.

Check staleness:
```bash
bash scripts/code-twin-sync-check.sh projects/{slug}/code-twin/ --json
```

Stale CTFs are safe for high-level planning. They are **not safe** for:
- Generating production code
- Security or compliance decisions
- Writing specs that depend on exact method signatures

## How to Maintain the Twin

1. **Init**: `bash scripts/code-twin-init.sh --project projects/{slug}`
2. **Generate CTFs**: `python3 scripts/code-twin-generate.py --file src/foo.py --output projects/{slug}/code-twin/application/`
3. **Lint**: `bash scripts/code-twin-lint.sh projects/{slug}/code-twin/application/foo.md`
4. **Check freshness**: `bash scripts/code-twin-sync-check.sh projects/{slug}/code-twin/ --json`
5. **Approve**: edit stub, verify content, change `status: DRAFT` → `status: STABLE`

## Anti-Patterns

| Anti-pattern | Risk | Mitigation |
|---|---|---|
| Using a stale CTF for production spec | Wrong implementation | Run sync-check before speccing |
| Setting `status: STABLE` without review | Incorrect CTF accepted | Humans must review before STABLE |
| CTF `token_budget > 800` | Context overflow | Linter blocks; split into parts |
| Real project names in CTFs committed publicly | Project leakage | Use `code-twin-anonymize.sh` |
| Trusting simulation output as ground truth | False confidence | Always verify against real code |

## Simulation Header

Every call to `code-twin-simulate.sh` **must** produce a first line of:
```
[SIMULATION — NOT GROUND TRUTH] confidence=X.XX
```

This header is **mandatory**. Never strip it from output.

## Tools

| Script | Purpose |
|---|---|
| `code-twin-init.sh` | Scaffold empty ACT structure |
| `code-twin-generate.py` | Generate CTFs from a source file |
| `code-twin-lint.sh` | Validate CTF frontmatter and seeds |
| `code-twin-sync-check.sh` | Detect stale CTFs |
| `code-twin-load.sh` | Lazy-load CTFs with token budget |
| `code-twin-simulate.sh` | Simulate function execution |
| `code-twin-validate-spec.sh` | Validate spec draft against ACT |
| `code-twin-extract.py` | Multi-file AST-light extractor |
| `code-twin-anonymize.sh` | Anonymize CTFs for public sharing |
