---
status: PROPOSED
---

# SPEC-SE-015 — Project Prospect (Pipeline-as-Code)

> **Priority:** P1 · **Estimate (human):** 6d · **Estimate (agent):** 6h · **Category:** standard · **Type:** sales pipeline + bid management + RFP response

## Objective

Give a 5000-person consultancy a **sovereign, agent-queryable opportunity pipeline** where pursuits live as `.md` files inside each tenant's pm-workspace, with structured qualification scoring (BANT/MEDDIC), bid/no-bid decision audit trails, proposal knowledge reuse from a local library, and a canonical handoff package that carries sales context into delivery without information loss.

The business problem: pre-sales in a Tier-1 consultancy is an expensive, high-churn activity. Solution architects at $250–400/hr are routinely burned on pursuits that should never have passed qualification. Win-rate visibility is poor. Historical proposals are locked in Salesforce attachments, Confluence pages, and email threads — unreachable by the team working the next bid. SPI Research benchmarks show the average pre-sales:sales ratio is 1:3 to 1:5; below 1:5, quality collapses. APMP data suggests RFP response costs range $30–150k per enterprise proposal.

Savia Enterprise turns the pursuit into code: a versioned, agent-queryable artifact that lets the bid team reuse knowledge from past proposals, qualify with traceable scoring, and hand off to delivery without the context gap that causes 15–30% margin erosion.

## Principles affected

- **#1 Soberanía del dato** — pursuit data lives as `.md` in the tenant repo, not in Salesforce attachments or Loopio SaaS. Portable, diff-able, survives any vendor disappearing.
- **#2 Independencia del proveedor** — adapters to Salesforce/HubSpot/Dynamics CRM are opt-in; the canonical pipeline is the `.md` tree. A consultancy that never uses CRM integration still has a working pipeline.
- **#4 Privacidad absoluta** — confidential pursuits stay N4-isolated per client-pod. No pursuit data aggregated in a vendor cloud. Sovereign LLM (Ollama via savia-dual) available for RFP drafting on sensitive bids.
- **#5 El humano decide** — bid/no-bid is always a human decision. Agents SCORE and RECOMMEND; they never auto-commit resources.

## Design

### Pipeline-as-Code — the canonical structure

```
tenants/{tenant-id}/pipeline/
├── PIPELINE.md             # Portfolio view: all active pursuits
├── pursuits/
│   ├── OPP-2026-001/       # One directory per opportunity
│   │   ├── pursuit.md      # Master pursuit record (YAML frontmatter)
│   │   ├── qualification.yaml  # BANT + MEDDIC scoring (agent-computed)
│   │   ├── bid-decision.md # Go/no-go record with rationale
│   │   ├── proposal/       # RFP response artifacts
│   │   │   ├── executive-summary.md
│   │   │   ├── technical-approach.md
│   │   │   ├── pricing.yaml
│   │   │   ├── team-profiles/
│   │   │   └── compliance-matrix.md
│   │   ├── handoff.md      # Sales→delivery handoff package
│   │   └── postmortem.md   # Win/loss analysis (post-decision)
│   └── OPP-2026-002/
│       └── ...
├── library/                # Reusable proposal knowledge
│   ├── capabilities/       # Standard capability statements per practice
│   ├── case-studies/       # Sanitized past engagement summaries
│   ├── team-bios/          # Pre-approved consultant profiles
│   └── templates/          # Proposal section templates per engagement type
└── scoring/
    ├── bant-weights.yaml   # Configurable BANT scoring weights
    └── meddic-weights.yaml # Configurable MEDDIC scoring weights
```

### Pursuit frontmatter (pursuit.md)

```yaml
---
opp_id: "OPP-2026-001"
tenant: "acme-consulting"
client: "megabank-eu"
title: "Core banking platform modernization"
stage: "qualification"   # lead | qualification | pursuit | proposal | negotiation | won | lost
engagement_type: "fixed-price"
estimated_value_eur: 1200000
estimated_duration_months: 8
probability_pct: 35
source: "referral"   # referral | rfp | rfi | inbound | outbound
key_contacts:
  - role: "economic-buyer"
    name_ref: "stakeholders.md#eb-001"
  - role: "champion"
    name_ref: "stakeholders.md#ch-001"
practice: "cloud-migration"
competitors: ["ibm-consulting", "capgemini"]
pursuit_team:
  - role: "account-executive"
    handle: "@ae-spain"
  - role: "solution-architect"
    handle: "@sa-cloud-01"
  - role: "bid-manager"
    handle: "@bid-mgr"
pre_sales_budget_hours: 120
pre_sales_spent_hours: 0
compliance_requirements: ["dora-banking", "gdpr-eu"]
next_milestone:
  what: "Qualification gate review"
  when: "2026-05-15"
---
```

### Qualification scoring (agentic, agent-computed)

The `prospect-qualifier` agent reads `pursuit.md`, queries the team for missing data, and produces `qualification.yaml`:

```yaml
bant:
  budget: { score: 3, max: 5, rationale: "Confirmed EUR 1.2M budget, signed off by CFO" }
  authority: { score: 4, max: 5, rationale: "Economic buyer identified, direct access confirmed" }
  need: { score: 5, max: 5, rationale: "Regulatory mandate (DORA) with hard deadline" }
  timing: { score: 4, max: 5, rationale: "RFP deadline 2026-06-01, decision Q3 2026" }
  total: 16
  max: 20
  pct: 80

meddic:
  metrics: { score: 4, rationale: "TCO reduction target documented" }
  economic_buyer: { score: 4, rationale: "CFO identified" }
  decision_criteria: { score: 3, rationale: "Draft, not finalized" }
  decision_process: { score: 2, rationale: "Unclear — multiple committees" }
  identify_pain: { score: 5, rationale: "Regulatory pressure explicit" }
  champion: { score: 4, rationale: "CTO aligned, active sponsor" }
  competition: { score: 3, rationale: "IBM and Capgemini shortlisted" }
  paper_process: { score: 1, rationale: "Procurement portal unknown" }
  total: 26
  max: 40
  pct: 65

recommendation: "GO — strong need (regulatory), identified buyer, acceptable
  competition. Risk: paper process unknown, may delay close."
bid_no_bid: pending   # pending | go | no-go
```

### Bid/no-bid decision record

After qualification, the practice leader makes the bid/no-bid decision. The record is explicit and auditable:

```yaml
---
opp_id: "OPP-2026-001"
decision: "go"
decided_by: "@practice-leader-cloud"
decided_on: "2026-05-16"
rationale: |
  BANT 80% + MEDDIC 65% = solid. Regulatory need is hard deadline.
  Pre-sales budget approved at 120h. Competition is known. Risk accepted
  on procurement process — will pursue with Ariba early-access request.
pre_sales_approved_hours: 120
estimated_cost_eur: 45000
risk_appetite: "moderate"
conditions:
  - "Solution architect must confirm feasibility by 2026-05-25"
  - "Legal must review NDA before first client meeting"
---
```

### Proposal library — sovereign knowledge reuse

The `library/` directory holds reusable proposal assets that agents can query:

- `library/capabilities/*.md` — standard capability statements per practice area.
- `library/case-studies/*.md` — sanitized past engagement summaries with results metrics.
- `library/team-bios/*.md` — pre-approved consultant profiles in a consistent format.
- `library/templates/*.md` — proposal section templates keyed by engagement type (fixed-price, T&M, outcome-based).

The `proposal-drafter` agent reads the RFP requirements, searches the library for relevant capability statements and case studies, and drafts a response that the bid manager reviews and edits. All drafting happens locally — no proposal content is sent to external APIs unless the tenant opts in (and savia-dual Ollama fallback is available for air-gap bids).

### Sales→Delivery handoff

When a pursuit moves to `won`, the `handoff-generator` agent produces `handoff.md`:

```yaml
---
handoff_type: "sales-to-delivery"
from: "pursuit-team"
to: "delivery-team"
opp_id: "OPP-2026-001"
generated_on: "2026-07-01"
sections:
  - client_context
  - key_relationships
  - proposal_commitments
  - pricing_assumptions
  - risk_register
  - compliance_requirements
  - lessons_from_pursuit
linked_sow: "definition/SOW.md"    # cross-reference to SE-017
---

# Sales→Delivery Handoff — OPP-2026-001

## Client Context
[auto-extracted from pursuit.md + qualification.yaml]

## Key Relationships
[from key_contacts, with notes on communication preferences]

## What We Committed To
[from proposal/ artifacts — specific deliverables, timelines, exclusions]

## Pricing Assumptions
[from pricing.yaml — rate cards, assumptions, contingency %]

## Known Risks
[from qualification.yaml low-scoring dimensions + bid-decision conditions]

## Compliance Requirements
[from pursuit.md compliance_requirements]

## Lessons from Pursuit
[from postmortem.md if the pursuit had any rejected proposals before winning]
```

This handoff bridges the gap that SPI Research documents as the #1 margin leak in consulting.

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `prospect-qualifier` | L1 | Reads pursuit.md, computes BANT + MEDDIC scoring, produces qualification.yaml. Never makes bid/no-bid decision. |
| `proposal-drafter` | L2 | Searches library/ for relevant content, drafts proposal sections. Local-only — uses savia-dual Ollama for air-gap bids. |
| `handoff-generator` | L2 | On pursuit win, compiles handoff.md from all pursuit artifacts + cross-references SE-017 SOW. |
| `win-loss-analyst` | L1 | On pursuit close (won or lost), generates postmortem.md with structured lessons, feeds back into library/ case studies. |

### New commands

| command | role | output |
|---------|------|--------|
| `/pursuit-init "Client Name" "Title"` | account-exec | Scaffolds OPP-YYYY-NNN directory from template. |
| `/pursuit-qualify OPP-2026-001` | account-exec | Runs `prospect-qualifier`, produces qualification.yaml. |
| `/pursuit-bid OPP-2026-001 go` | practice-leader | Records bid/no-bid decision with rationale prompt. |
| `/pursuit-draft OPP-2026-001` | bid-manager | Invokes `proposal-drafter` to generate proposal sections. |
| `/pursuit-handoff OPP-2026-001` | account-exec | On win, invokes `handoff-generator`. |
| `/pursuit-close OPP-2026-001 won` | account-exec | Marks stage=won/lost, invokes `win-loss-analyst`. |
| `/pipeline-view [--stage X]` | anyone | ASCII table of all active pursuits with stage, value, probability. |

### Events

```json
{"event": "pursuit.qualified", "tenant": "...", "opp_id": "...", "bant_pct": 80, "meddic_pct": 65}
{"event": "pursuit.bid_decided", "tenant": "...", "opp_id": "...", "decision": "go"}
{"event": "pursuit.won", "tenant": "...", "opp_id": "...", "value_eur": 1200000}
{"event": "pursuit.lost", "tenant": "...", "opp_id": "...", "competitor_won": "ibm-consulting"}
{"event": "pursuit.handoff_completed", "tenant": "...", "opp_id": "...", "linked_sow": "..."}
```

Events consumed by SE-016 (valuation), SE-017 (SOW init), SE-018 (billing setup), SE-019 (evaluation baseline), SE-020 (resource allocation).

## Acceptance criteria

1. Regla `docs/rules/domain/pipeline-as-code.md` ≤150 lines documents pursuit schema, 4 agents, qualification workflow, bid/no-bid gate, handoff flow.
2. JSON Schema `pursuit-frontmatter.schema.json` validates the 15+ required frontmatter fields.
3. `scripts/pursuit-validate.sh` detects the 8 top failure modes (missing qualification before pursuit stage, missing bid-decision before proposal stage, incomplete BANT/MEDDIC, orphan pursuits >90d without stage change, handoff missing for won pursuits, team-without-SA, duplicate OPP-IDs, library references pointing at nonexistent assets).
4. `/pursuit-qualify` produces a `qualification.yaml` that passes schema validation with all BANT+MEDDIC dimensions scored and justified.
5. `/pursuit-draft` generates a proposal skeleton using only `library/` assets — no external API calls in air-gap mode.
6. `/pursuit-handoff` cross-references `definition/SOW.md` from SE-017 if it exists.
7. `win-loss-analyst` generates postmortem with structured lessons that the `proposal-drafter` can query on the next bid.
8. `/pipeline-view` ASCII output renders correctly with 20+ active pursuits.
9. 20+ BATS tests, SPEC-055 score ≥ 80, coverage delta ≥ 0.
10. Air-gap: full flow works offline (Ollama fallback for proposal drafting).
11. `pr-plan` passes 11/11 gates.

## Out of scope

- CRM adapter implementations (Salesforce / HubSpot / Dynamics) — SE-015 defines the contract surface; adapters are SE-003 MCP catalog extensions.
- Procurement portal integration (Ariba, Coupa, Jaggaer) — manual export for v1.
- Revenue forecasting with Monte Carlo — out of scope for v1 (may be SE-016 territory).
- Contract negotiation workflow (covered by SE-017 change requests).
- FCPA/bribery compliance logging — acknowledged in risk section, not implemented.
- Pricing engine with margin optimization — `pricing.yaml` is input, not computed.
- LinkedIn Sales Navigator integration — potential future adapter.

## Dependencies

- **Blocked by:** SE-001 (layer contract), SE-002 (multi-tenant isolation).
- **Blocks:** SE-016 (valuation consumes `pursuit.qualified` events for ROI), SE-017 (SOW init triggered by `pursuit.won`), SE-018 (billing setup triggered by `pursuit.won`), SE-019 (evaluation baseline includes pursuit cost), SE-020 (resource allocation queries pursuit pipeline for demand forecast).
- **Soft deps:** SE-003 (MCP catalog — eventual CRM adapters), SE-005 (sovereign deployment — Ollama for air-gap bids), SE-006 (governance — audit trail for bid decisions).

## Migration path

- Reversible: feature-flag `PIPELINE_AS_CODE_ENABLED=false` in tenant manifest.
- Import: `scripts/pipeline-import.sh` reads a CSV export from Salesforce/HubSpot and scaffolds pursuit directories. One-time migration tool.
- Coexistence: tenants without `pipeline/` directory operate normally; delivery features don't require a pipeline.

## Impact statement

The opportunity pipeline is where a consultancy's revenue starts. A system that makes qualification traceable, proposal drafting efficient, and sales→delivery handoff explicit eliminates the three costliest failure modes in consulting pre-sales: pursuing bad bids (qualification), re-inventing proposals (library reuse), and losing context at handoff (handoff.md). For a 5000-person consultancy running 100+ active pursuits, improving win rate by 5 percentage points translates directly to millions in annual revenue.

## Sources

- APMP Body of Knowledge (Association of Proposal Management Professionals)
- SPI Research Professional Services Maturity Benchmark 2024
- BANT qualification framework (IBM origin)
- MEDDIC / MEDDPICC methodology (PTC/Salesforce documentation)
- SPIN Selling (Neil Rackham, 1988)
- ISO 9001:2015 clause 8.2 (review of customer requirements before commitment)
- DORA (EU 2022/2554) — referenced from SE-014 for compliance-tagged pursuits
- EU AI Act (2024) — bid-scoring algorithms as high-risk HR-adjacent decisions
