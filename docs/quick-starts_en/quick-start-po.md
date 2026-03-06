# Quick Start — Product Owner

> 🦉 Hi, Product Owner. I'm Savia. I help you measure the impact of what you deliver, manage stakeholders, and keep the backlog aligned with strategy. Here's the essentials.

---

## First 10 minutes

```
/value-stream-map --bottlenecks
```
I map the end-to-end value stream and detect bottlenecks. You'll see where time is lost.

```
/backlog-prioritize --strategy-aligned
```
I prioritize the backlog aligning it with strategic goals (OKRs if defined).

```
/feature-impact --roi
```
I analyze the impact of delivered features: estimated ROI, engagement, and technical load generated.

---

## Your daily routine

**Sprint start** — `/backlog-groom --top 10` reviews the top 10 items. `/pbi-decompose` breaks down those ready for development.

**Weekly** — `/stakeholder-report` generates the stakeholder report with delivery metrics and objective alignment.

**Before release** — `/release-readiness` verifies everything is ready: technical capacity, mitigated risks, prepared communications.

**Each sprint** — `/outcome-track --release` records the business outcomes of what was delivered. This is what proves value.

**Quarterly** — `/okr-track --trend` reviews OKR progress. `/strategy-map` visualizes dependencies between initiatives.

---

## How to talk to me

| You say... | I run... |
|---|---|
| "What should I prioritize?" | `/backlog-prioritize` |
| "What's the impact of this feature?" | `/feature-impact` |
| "Prepare the stakeholder report" | `/stakeholder-report` |
| "Are we ready for release?" | `/release-readiness` |
| "Break down this PBI" | `/pbi-decompose {id}` |
| "Where are we losing time in the flow?" | `/value-stream-map --bottlenecks` |

---

## Where your files are

```
output/
├── reports/           ← stakeholder reports, feature impact
├── backlog-snapshots/ ← backlog state snapshots
└── okr-tracking/      ← OKR tracking

.claude/commands/
├── backlog-*.md       ← groom, prioritize, patterns
├── feature-*.md       ← feature impact analysis
├── stakeholder-*.md   ← stakeholder reporting
├── okr-*.md           ← OKR definition and tracking
└── release-*.md       ← readiness checks
```

---

## How your work connects

The PBIs you prioritize get broken down into tasks the team implements. The velocity of those items feeds the PM's sprint forecast. The feature impact you measure aggregates into the CEO's portfolio overview. The OKRs you define align the backlog with strategy, and the value stream map shows if the flow is efficient. If you detect a bottleneck, that translates into concrete actions for the Tech Lead (tech debt) or PM (load redistribution).

---

## Next steps

- [Sprints and reports](../readme_en/04-uso-sprint-informes.md)
- [Data flow](../data-flow-guide-en.md)
- [Scenario guides](../guides_en/README.md)
- [Full commands](../readme/12-comandos-agentes.md)
