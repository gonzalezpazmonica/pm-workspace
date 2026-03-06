# Quick Start — CEO / CTO

> 🦉 Hi. I'm Savia. For you, I filter only what requires executive decisions: portfolio status, DORA metrics, AI governance, and alerts that can't wait. No noise, just signal.

---

## First 10 minutes

```
/portfolio-overview --deps
```
Bird's-eye view of all projects: status, cross-team dependencies, and risk traffic light.

```
/ceo-alerts
```
Only alerts that require your decision: at-risk sprints, exceeded budgets, open incidents.

```
/kpi-dora
```
Team DORA metrics: deployment frequency, lead time, change failure rate, time to restore.

---

## Your daily routine

**Monday** — `/portfolio-overview` for the weekly snapshot. `/ceo-alerts` for what's urgent.

**Biweekly** — `/ceo-report --format pptx` generates the board presentation with traffic lights, metrics, and recommendations.

**Monthly** — `/org-metrics --trend 6` for organizational trends. `/ai-exposure-audit` to understand AI's impact on team roles.

**Quarterly** — `/governance-report` consolidates compliance status. `/okr-track --trend` shows strategic progress.

---

## How to talk to me

| You say... | I run... |
|---|---|
| "How are the projects going?" | `/portfolio-overview` |
| "What needs my attention?" | `/ceo-alerts` |
| "Give me the board report" | `/ceo-report --format pptx` |
| "How are we doing on DORA?" | `/kpi-dora` |
| "What's AI's risk to the team?" | `/ai-exposure-audit` |
| "Are we meeting governance?" | `/governance-report` |

---

## Where your files are

```
output/
├── reports/
│   ├── ceo-report-*.pptx   ← executive reports
│   ├── portfolio-*.md       ← portfolio views
│   └── governance-*.md      ← compliance reports
└── alerts/                  ← alert history

.claude/commands/
├── ceo-*.md                 ← report, alerts
├── portfolio-*.md           ← overview, deps
├── governance-*.md          ← audit, report, certify
└── ai-*.md                  ← exposure audit, model cards
```

---

## How your work connects

Everything you see in `/ceo-report` comes from below: team hours (time tracking) → project costs (cost-management) → margins. Sprint velocity → delivery forecast. QA tests → change failure rate (DORA). Tech Lead ADRs → decision traceability. PM burnout alerts → wellbeing. Your view is the aggregation of all team work, filtered so you only see what needs your decision.

The `/ai-exposure-audit` uses O*NET data to calculate how much of each role is automatable with AI. This feeds reskilling plans and workforce forecasting — strategic executive decisions.

---

## Next steps

- [AI Augmentation by sector](../ai-augmentation-opportunities-en.md)
- [AI governance](../readme_en/10-kpis-rules.md)
- [Data flow guide](../data-flow-guide-en.md)
- [Scenario guides](../guides_en/README.md)
