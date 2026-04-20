---
status: PROPOSED
---

# SPEC-SE-024 — Client Health Intelligence

> **Priority:** P2 · **Estimate (human):** 5d · **Estimate (agent):** 5h · **Category:** standard · **Type:** account health scoring + relationship mapping + retention signals

## Objective

Give a 5000-person consultancy a **data-driven client health scoring
system** that aggregates project delivery signals (margin trends,
escalation frequency, NPS, scope changes, payment timeliness) into an
account-level health score, maps stakeholder relationships, and surfaces
churn risk before it materializes — all from data already flowing through
Savia's project lifecycle (SE-014..020).

Gartner reports that 65% of traditional health scores fail to predict
churn. The problem: scores are based on lagging indicators (survey
results) not leading ones (escalation patterns, scope creep rate,
payment delays). Savia has leading indicators in real time — every
change request (SE-017), every billing dispute (SE-018), every
evaluation score (SE-019) is already versioned in `.md`.

## Design

### Health score model (6 dimensions, 0-100)

```yaml
client_health:
  client: "acme-banking"
  as_of: "2026-04-12"
  score: 72
  trend: "declining"          # improving | stable | declining
  dimensions:
    delivery: { score: 85, weight: 0.25, signals: "2/2 projects on-time" }
    commercial: { score: 60, weight: 0.20, signals: "margin erosion 5% last quarter" }
    relationship: { score: 70, weight: 0.20, signals: "champion change at client" }
    satisfaction: { score: 80, weight: 0.15, signals: "NPS 8, stable" }
    growth: { score: 65, weight: 0.10, signals: "pipeline: 1 pursuit, down from 3" }
    payment: { score: 72, weight: 0.10, signals: "DSO 75 days, up from 60" }
  alerts:
    - "Champion departure detected — new stakeholder onboarding needed"
    - "Pipeline shrinkage — 1 active pursuit vs 3 last quarter"
  risk_level: "medium"        # low | medium | high | critical
```

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `health-scorer` | L1 | Computes health score from project lifecycle data |
| `relationship-mapper` | L1 | Tracks stakeholder changes across projects |
| `churn-predictor` | L1 | Flags accounts with 3+ declining dimensions |

### New commands

| command | output |
|---------|--------|
| `/client-health CLIENT` | Health dashboard for one client |
| `/client-health-all [--risk high+]` | Portfolio-wide health view |
| `/client-stakeholders CLIENT` | Relationship map |

## Acceptance criteria

1. Health score computed from 6 dimensions with configurable weights.
2. Trend detection over 3+ periods (improving/stable/declining).
3. Alert when 3+ dimensions decline simultaneously.
4. Stakeholder changes tracked from SE-017 SOW contacts.
5. 15+ BATS tests, SPEC-055 ≥ 80. Air-gap capable.

## Dependencies

- **Blocked by:** SE-001, SE-002, SE-017 (contacts), SE-018 (commercial), SE-019 (satisfaction).
- **Integrates with:** SE-015 (pipeline growth dimension), SE-020 (cross-project signals).

## Sources

- Gartner "Customer Health Score" research (65% failure rate)
- Gainsight, Totango — customer success platform patterns (adapted for services)
- Bain NPS methodology (Net Promoter System)
