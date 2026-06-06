---
context_tier: L2
token_budget: 600
---

# Context Tier Budgets — SPEC-181

> Every `docs/rules/domain/*.md` must declare `context_tier` and `token_budget`.

## Tier Definitions

| Tier | Budget    | Load policy          | Contents |
|------|-----------|----------------------|----------|
| L0   | <=200 tok | Always eager         | Identity only: savia.md, active-user.md |
| L1   | <=2000 tok| Eager per session    | CLAUDE.md, caveman-default, radical-honesty, autonomous-safety |
| L2   | <=5000 tok| On-demand frequent   | agents-catalog, pm-workflow, language-packs, critical-rules-extended |
| L3   | <=20000 tok| On-demand explicit  | Long guides, architecture patterns, historical decisions |

## Tier Assignment Criteria

### L0 — <=200 tokens
- File loaded in every single turn (identity anchors only).
- Removing it breaks Savia core persona or active-user resolution.

### L1 — <=2000 tokens
- Loaded at session start for operational baseline.
- Affects response format, honesty, or safety constraints.
- Files exceeding 2000 tokens must be split or demoted to L2.

### L2 — <=5000 tokens
- On-demand when a relevant task type is detected in the session.
- Operational reference: catalogs, workflow rules, config tables.
- Files >5000 tokens must be split or demoted to L3.

### L3 — <=20000 tokens
- On-demand explicit user request or specialized agent invocation.
- Long-form reference: architecture patterns, compliance, historical context.
- Files exceeding 20K must be chunked.

## Invariant

    sum(L0 budgets) + sum(L1 budgets) <= 3000 tokens

Verified by `scripts/audit-context-budget.sh`.

## Frontmatter Format

    ---
    context_tier: L1
    token_budget: 1200
    ---

## Enforcement

- `scripts/audit-context-budget.sh` — sums per tier, exits 1 if L0+L1 > 3000.
- BATS: `tests/test-spec-181-context-budgets.bats`.
- Ref: SPEC-181 AC1-AC7.
