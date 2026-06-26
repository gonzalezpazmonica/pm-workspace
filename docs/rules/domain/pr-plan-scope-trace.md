---
context_tier: L3
token_budget: 960
spec: SE-079
---

# G13 Scope-trace audit — pr-plan gate

**Gate**: G13 `Scope-trace audit` — runs as part of `scripts/pr-plan.sh`.  
**Pattern**: Genesis B9 GOAL STEWARD + B8 ATTENTION ANCHOR (SE-080).  
**Spec**: `docs/propuestas/SE-079-pr-plan-scope-trace-gate.md`.

## Purpose

Every file changed in a PR must trace back to an acceptance criterion of the
spec that justifies the PR. Catches silent scope-creep before it reaches code
review.

## How it works

1. **Detect spec ref** — searches in order:
   - `Spec ref: SE-XXX` or any `SE-/SPEC-NNN` in `.pr-summary.md`
   - Commit messages on the branch
   - Branch name (`agent/se079-...` → `SE-079`)
   - If no spec found → **WARN, no fail** (valid for docs/tooling PRs).

2. **Load ACs** — parses `- [ ] AC-XX …` / `- [x] AC-XX …` lines from the
   spec file in `docs/propuestas/`.

3. **Check each changed file** against:
   - **Whitelist**: `CHANGELOG.d/*`, `CHANGELOG.md`, `.scm/*`,
     `.confidentiality-signature`, `.pr-summary.md` — always accepted.
   - **Self-spec match**: the spec file itself is in-scope.
   - **Path hint match**: an AC explicitly mentions the file path.
   - **Token overlap**: tokenise `basename` (strip extension, split on `-_`);
     match if ≥1 token of length ≥4 appears in AC text (case-insensitive).

4. If ≥1 file fails all checks → **FAIL** with a table `file → NO MATCH`.
   Table is capped at 10 rows; excess shown as `… (N more)`.

## Multi-spec PRs

Sprint batch PRs that touch multiple specs list all spec IDs in
`.pr-summary.md`. G13 unions AC tokens from all referenced specs — a file
needs to trace to any one of them.

## Override

Add this line to `.pr-summary.md` to skip the gate for a specific PR:

```
Scope-trace: skip — <reason of at least 10 characters>
```

The reason is recorded in the gate output. A reason shorter than 10 chars
causes a FAIL (prevents empty bypasses).

## Constraints

- **PURE_BASH** — zero LLM calls, zero external dependencies.
- Never fails for PRs without a detectable spec (only WARNs).
- Never blocks `chore/*` commits tagged `[skip-scope]` (existing convention).

## Tests

`tests/structure/test-pr-plan-g13-scope-trace.bats` — 25 BATS tests covering
happy paths, failure paths, whitelist, override, multi-spec, and edge cases.
