# Business-Case-as-Code — Valuation Lifecycle (SE-016)

> Living business cases that agents recompute. Humans decide stop/go.

## Structure

Each project valuation lives in `tenants/{tenant}/projects/{project}/valuation/`.

Required files:
- `business-case.md` — master case with YAML frontmatter (15+ fields)
- `assumptions.yaml` — all numerical assumptions with source + validated date
- `risk-register.yaml` — quantified risks (probability x impact)
- `benefit-schedule.yaml` — expected benefit timeline

Optional:
- `actuals/cost-actuals.yaml` — linked to billing (SE-018)
- `actuals/benefit-actuals.yaml` — post-delivery measured benefits
- `reviews/review-{90d|180d|365d}.md` — benefit realization checks
- `portfolio-score.yaml` — computed aggregate for investment committee

## Frontmatter (business-case.md)

Required: `case_id`, `tenant`, `project`, `opp_id`, `status`,
`investment_eur`, `estimated_npv_eur`, `estimated_irr_pct`,
`payback_months`, `risk_adjusted_npv_eur`, `benefit_realization_status`,
`last_recomputed`, `variance_alerts`.

Status: `draft | active | paused | completed | killed`.
Benefit: `not-started | tracking | realized | missed`.

## Variance Thresholds

| Dimension | Green | Amber | Red |
|-----------|-------|-------|-----|
| Cost | <15% | 15-30% | >30% |
| Timeline | <20% | 20-40% | >40% |
| Benefit | <25% | 25-50% | >50% (or not measured) |

Red on cost OR negative risk-NPV triggers kill recommendation.

## 4 Agents

| Agent | Level | Purpose |
|-------|-------|---------|
| valuation-recomputer | L1 | Recomputes NPV/IRR/risk-NPV from actuals |
| benefit-reviewer | L1 | Generates 90/180/365d review files |
| portfolio-scorer | L1 | Aggregates all tenant cases into dashboard |
| valuation-sentinel | L1 | Monitors variance, emits kill recommendations |

## Validation (6 failure modes)

`scripts/case-validate.sh` detects:
1. Missing assumptions source (assumption without `source` field)
2. Stale assumptions >90d without revalidation
3. Risk without probability or impact
4. Benefit schedule without review dates
5. Cost variance exceeding threshold without alert
6. Duplicate case IDs across tenant

## Commands

`/case-init`, `/case-recompute`, `/case-review`, `/portfolio-view`, `/case-kill-check`.

## NPV Formula

```
NPV = sum(cash_flow_t / (1 + discount_rate)^t) for t=0..N
IRR = discount_rate where NPV = 0 (Newton-Raphson approx)
Risk-adjusted NPV = NPV * (1 - sum(risk_probability * normalized_impact))
```

## Privacy

Business case data is N4 (per-tenant, gitignored). All computation local.
No financial data sent to external APIs.
