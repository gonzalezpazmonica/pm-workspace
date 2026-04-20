---
status: PROPOSED
---

# SPEC-SE-016 — Project Valuation (Business-Case-as-Code)

> **Priority:** P2 · **Estimate (human):** 6d · **Estimate (agent):** 6h · **Category:** standard · **Type:** portfolio valuation + benefit realization + risk-adjusted ROI

## Objective

Give a 5000-person consultancy a **living, agent-maintained business case**
per engagement that stays linked to delivery actuals, automatically flags
assumption drift, tracks benefit realization at 90/180/365 days post-delivery,
and feeds a portfolio dashboard that an investment committee can use to
rebalance the project portfolio quarterly — all stored as `.md` in the
tenant's pm-workspace, auditable in git, computed locally.

PMI Pulse of the Profession reports that only ~30% of organisations track
benefit realization. The Standish CHAOS numbers are worse: ~30% of large
IT projects deliver expected benefits. The root cause is the same in both
cases: the business case is a PowerPoint written before delivery starts,
parked in a folder, never revisited. Assumptions are disconnected from
actuals. The investment committee sees a score from a frozen model while
reality has moved.

Savia Enterprise turns the business case into a living `.md` with YAML
frontmatter that agents recompute on every meaningful commit — linking
estimated cost to actual burn, estimated benefit to actual outcomes,
and estimated risk to actual incidents.

## Principles affected

- **#1 Soberanía del dato** — business cases are `.md` in the tenant repo.
- **#2 Independencia del proveedor** — adapters to Anaplan / Planview are
  opt-in. The canonical valuation is the `.md`.
- **#5 El humano decide** — project stop/go is ALWAYS human. Agents
  flag variance; humans decide.

## Design

### Business-Case-as-Code structure

```
tenants/{tenant-id}/projects/{project-id}/valuation/
├── business-case.md          # Master case (YAML frontmatter + prose)
├── assumptions.yaml          # All numerical assumptions (traceable)
├── risk-register.yaml        # Quantified risk × probability
├── benefit-schedule.yaml     # Expected benefit realisation timeline
├── actuals/
│   ├── cost-actuals.yaml     # Linked to billing (SE-018) or timesheet
│   └── benefit-actuals.yaml  # Post-delivery measured benefits
├── reviews/
│   ├── review-90d.md         # Benefit check at 90 days
│   ├── review-180d.md        # Benefit check at 180 days
│   └── review-365d.md        # Benefit check at 365 days
└── portfolio-score.yaml      # Computed aggregate for investment committee
```

### Business-case frontmatter

```yaml
---
case_id: "BC-2026-001"
tenant: "acme-consulting"
project: "erp-migration"
opp_id: "OPP-2026-001"           # link back to SE-015 pursuit
sow_id: "acme-erp-migration-2026" # link to SE-017 SOW
status: "active"       # draft | active | paused | completed | killed
investment_eur: 420000
estimated_npv_eur: 650000
estimated_irr_pct: 28
payback_months: 14
risk_adjusted_npv_eur: 520000    # NPV × (1 - weighted_risk_factor)
benefit_realization_status: "tracking"  # not-started | tracking | realized | missed
esg_impact:
  carbon_scope_3_kg_saved: 0
  diversity_impact: "neutral"
  sustainability_score: "n/a"
last_recomputed: "2026-04-12T02:15:00Z"
variance_alerts:
  cost: { threshold_pct: 15, current_pct: 8, status: "green" }
  timeline: { threshold_pct: 20, current_pct: 5, status: "green" }
  benefit: { threshold_pct: 25, current_pct: null, status: "pending" }
---
```

### Assumptions traceability

`assumptions.yaml` contains every numerical assumption with its source:

```yaml
assumptions:
  - id: "A-001"
    parameter: "hourly_rate_eur"
    value: 150
    source: "pricing.yaml from SE-015 pursuit"
    last_validated: "2026-04-01"
  - id: "A-002"
    parameter: "annual_maintenance_savings_eur"
    value: 180000
    source: "client estimate in SOW section 1.2"
    last_validated: "2026-04-01"
  - id: "A-003"
    parameter: "adoption_rate_pct_year1"
    value: 70
    source: "industry benchmark Gartner 2025"
    last_validated: "2026-04-01"
```

Agents flag assumptions that haven't been validated in >90 days.

### Risk register with quantified impact

```yaml
risks:
  - id: "R-001"
    description: "Data migration exceeds 30-entity scope"
    probability: 0.30
    impact_eur: 80000
    expected_loss_eur: 24000    # probability × impact
    mitigation: "Phased migration with exit gate at entity 15"
    owner: "@delivery-manager"
    status: "open"
  - id: "R-002"
    description: "Key resource departure mid-project"
    probability: 0.15
    impact_eur: 120000
    expected_loss_eur: 18000
    mitigation: "Cross-train backup on critical path tasks"
    owner: "@practice-leader"
    status: "open"
```

`risk_adjusted_npv = npv × (1 - sum(probability × normalized_impact))`.

### Benefit realization reviews

At 90, 180, and 365 days post-delivery, the `benefit-reviewer` agent
generates a review file comparing planned vs actual benefits:

```yaml
---
review_type: "90d"
case_id: "BC-2026-001"
review_date: "2026-10-15"
reviewer: "@benefit-realization-manager"
planned_benefits_at_90d:
  - { metric: "maintenance_cost_reduction_eur", expected: 45000, actual: 38000, delta_pct: -15 }
  - { metric: "processing_time_reduction_pct", expected: 30, actual: 22, delta_pct: -27 }
overall_realization_pct: 77
recommendation: "On track but below target. Adoption rate lower than assumed.
  Recommend targeted training push in Q4."
---
```

### Portfolio dashboard (computed, not stored)

The `portfolio-scorer` agent aggregates all `business-case.md` files
across the tenant's projects into a portfolio view:

```
/portfolio-view [--sort risk-adjusted-npv] [--filter active]

┌─────────────────────┬────────┬──────────┬──────────┬─────────┬───────┐
│ Project             │ NPV    │ Risk-NPV │ IRR      │ Payback │ Alert │
├─────────────────────┼────────┼──────────┼──────────┼─────────┼───────┤
│ ERP Migration       │  650K  │   520K   │  28%     │ 14mo    │       │
│ Cloud Platform      │ 1.2M   │   840K   │  35%     │ 10mo    │       │
│ Data Lake           │  380K  │   190K   │  12%     │ 22mo    │ cost  │
│ Legacy Decommission │  280K  │   252K   │  45%     │  6mo    │       │
└─────────────────────┴────────┴──────────┴──────────┴─────────┴───────┘
```

### Kill recommendation

If cost variance exceeds 30% OR risk-adjusted-NPV turns negative, the
`valuation-sentinel` agent emits a structured recommendation:

```yaml
alert:
  type: "kill-recommendation"
  case_id: "BC-2026-003"
  project: "data-lake"
  reasons:
    - "Cost overrun at 34% (threshold 30%)"
    - "Risk-adjusted NPV now negative (-12K) due to R-003 materializing"
  sunk_cost_eur: 185000
  remaining_commitment_eur: 95000
  recommendation: "Stop and salvage. Estimated salvage value: 120K."
  decision_needed_by: "2026-05-01"
```

This is ALWAYS a recommendation. The investment committee decides.

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `valuation-recomputer` | L1 | Reads business-case.md + actuals, recomputes NPV/IRR/risk-NPV. Runs on commit to actuals or risk-register. |
| `benefit-reviewer` | L1 | Generates 90/180/365d review files by comparing planned vs actual benefits. |
| `portfolio-scorer` | L1 | Aggregates all tenant business cases into a portfolio view. |
| `valuation-sentinel` | L1 | Monitors variance thresholds and emits kill recommendations. |

### New commands

| command | role | output |
|---------|------|--------|
| `/case-init OPP-2026-001` | engagement-mgr | Scaffolds `valuation/` from pursuit and SOW data. |
| `/case-recompute BC-2026-001` | anyone | Forces recomputation of NPV/IRR/risk-NPV. |
| `/case-review BC-2026-001 90d` | benefit-mgr | Generates benefit realization review. |
| `/portfolio-view [--sort X]` | investment-committee | ASCII portfolio dashboard. |
| `/case-kill-check` | portfolio-mgr | Runs sentinel across all active cases. |

### Events

```json
{"event": "case.recomputed", "case_id": "...", "npv_eur": 650000, "risk_npv_eur": 520000}
{"event": "case.variance_alert", "case_id": "...", "dimension": "cost", "current_pct": 34}
{"event": "case.kill_recommended", "case_id": "...", "reason": "risk-adjusted NPV negative"}
{"event": "case.benefit_reviewed", "case_id": "...", "review_type": "90d", "realization_pct": 77}
```

## Acceptance criteria

1. Regla `docs/rules/domain/business-case-as-code.md` ≤150 lines.
2. JSON Schema for `business-case.md` frontmatter validates 15+ fields.
3. `scripts/case-validate.sh` detects 6 failure modes (missing assumptions source, stale assumptions >90d, risk without probability, benefit schedule without review dates, cost variance exceeding threshold without alert, duplicate case IDs).
4. `/case-init` scaffolds from SE-015 pursuit + SE-017 SOW data.
5. `valuation-recomputer` produces correct NPV/IRR given test inputs.
6. `/portfolio-view` renders with 10+ active cases.
7. `valuation-sentinel` emits kill recommendation when threshold exceeded.
8. Benefit realization review cross-references actuals from SE-018.
9. 20+ BATS tests, SPEC-055 score ≥ 80.
10. Air-gap capable. `pr-plan` passes 11/11 gates.

## Out of scope

- Full financial modeling engine (Anaplan-level) — v1 is formulaic NPV/IRR.
- Monte Carlo simulation for risk — future enhancement.
- ESG carbon accounting engine — v1 has placeholder fields.
- Integration with ERP (SAP FI/CO, Oracle Financials) for actuals — adapter surface defined, not implemented.
- Board-level reporting beyond ASCII table — PowerPoint export is a future adapter.

## Dependencies

- **Blocked by:** SE-001, SE-002, SE-015 (pursuit provides opportunity data).
- **Blocks:** SE-018 (billing references business-case cost structure), SE-019 (evaluation compares valuation predictions to actuals), SE-020 (portfolio-level resource allocation uses portfolio scores).
- **Soft deps:** SE-017 (SOW provides contract value), SE-014 (release events trigger actuals update).

## Migration path

- Reversible: feature-flag `VALUATION_ENABLED=false`.
- Import: `scripts/case-import.sh` reads business case from Excel/PPTX template.
- Coexistence: projects without `valuation/` skip all valuation logic.

## Impact statement

Benefit realization is the dark matter of project management: everyone believes it matters, nobody measures it. A living business case that auto-flags when assumptions drift from reality converts the investment committee from a rubber-stamp to a data-driven governance body. For a consultancy managing a portfolio of 50+ active projects worth EUR 30M+, catching one project that should be killed 3 months early saves more than the entire engineering effort of this spec.

## Sources

- PMI Standard for Portfolio Management, 4th Edition
- PMBOK 7th Edition — Value Delivery Performance Domain
- ISO 21504:2015 — Portfolio management guidance
- SAFe Lean Portfolio Management
- PMI Pulse of the Profession (benefit realization statistics)
- Standish Group CHAOS Report (project success statistics)
- EU CSRD (Corporate Sustainability Reporting Directive) for ESG fields
