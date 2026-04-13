# Pipeline-as-Code — Pursuit Lifecycle (SE-015)

> Pursuits live as versioned `.md` files. Agents score and recommend. Humans decide.

## Pursuit Schema

Each pursuit lives in `tenants/{tenant}/pipeline/pursuits/OPP-YYYY-NNN/`.

Required files:
- `pursuit.md` — master record with YAML frontmatter (15+ fields)
- `qualification.yaml` — BANT + MEDDIC scoring (agent-computed)
- `bid-decision.md` — go/no-go record (human decision, never agent)

Optional:
- `proposal/` — RFP response artifacts
- `handoff.md` — sales-to-delivery package (generated on win)
- `postmortem.md` — win/loss analysis

## Frontmatter (pursuit.md)

Required fields: `opp_id`, `tenant`, `client`, `title`, `stage`, `engagement_type`,
`estimated_value_eur`, `probability_pct`, `source`, `practice`, `pursuit_team`,
`pre_sales_budget_hours`, `pre_sales_spent_hours`, `next_milestone`.

Stages: `lead | qualification | pursuit | proposal | negotiation | won | lost`.

## Stage Gates

| Transition | Gate |
|------------|------|
| lead → qualification | pursuit.md with all required fields |
| qualification → pursuit | qualification.yaml exists, BANT scored |
| pursuit → proposal | bid-decision.md exists, decision=go |
| proposal → negotiation | proposal/ directory with executive-summary.md |
| negotiation → won/lost | human decision recorded |
| won → delivery | handoff.md generated, linked to SOW (SE-017) |

## 4 Agents

| Agent | Level | Purpose |
|-------|-------|---------|
| prospect-qualifier | L1 | Computes BANT + MEDDIC. Never decides. |
| proposal-drafter | L2 | Drafts from library/ assets. Local-only in air-gap. |
| handoff-generator | L2 | Compiles handoff.md from all pursuit artifacts. |
| win-loss-analyst | L1 | Generates postmortem with structured lessons. |

## Validation (8 failure modes)

`scripts/pursuit-validate.sh` detects:
1. Missing qualification before pursuit stage
2. Missing bid-decision before proposal stage
3. Incomplete BANT/MEDDIC (dimensions without score)
4. Orphan pursuits >90d without stage change
5. Handoff missing for won pursuits
6. Team without solution-architect role
7. Duplicate OPP-IDs across tenant
8. Library references pointing at nonexistent assets

## Proposal Library

`tenants/{tenant}/pipeline/library/` holds reusable assets:
- `capabilities/*.md` — standard capability statements
- `case-studies/*.md` — sanitized engagement summaries
- `team-bios/*.md` — pre-approved consultant profiles
- `templates/*.md` — proposal section templates

## Commands

`/pursuit-init`, `/pursuit-qualify`, `/pursuit-bid`, `/pursuit-draft`,
`/pursuit-handoff`, `/pursuit-close`, `/pipeline-view`.

## Events

Emitted to SE-006 audit trail: `pursuit.qualified`, `pursuit.bid_decided`,
`pursuit.won`, `pursuit.lost`, `pursuit.handoff_completed`.
Consumed by SE-016 (valuation), SE-017 (SOW), SE-018 (billing).

## Privacy

Pursuit data is N4 (per-tenant, gitignored from public repo). Proposal
drafting uses savia-dual Ollama fallback for air-gap bids. No pursuit
content sent to external APIs without explicit tenant opt-in.
