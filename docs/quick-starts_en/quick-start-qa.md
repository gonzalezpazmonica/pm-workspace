# Quick Start — QA

> 🦉 Hi, QA. I'm Savia. I help with test plans, coverage, regression, and quality gates. Quality is my obsession as much as yours.

---

## First 10 minutes

```
/qa-dashboard MyProject
```
Quality panel: current coverage, flaky tests, open bugs, and escape rate.

```
/testplan-generate --sprint
```
I generate a test plan based on the current sprint items and their SDD specs.

```
/qa-regression-plan --pr {number}
```
I analyze the impact of a PR's changes and recommend which tests to run.

---

## Your daily routine

**Sprint start** — `/testplan-generate --sprint` to have the test plan from day 1. Each SDD spec already defines acceptance criteria.

**On each PR** — `/qa-regression-plan --pr {n}` calculates which tests are needed. The automated code review already checks domain rules.

**When bugs arrive** — `/qa-bug-triage {bug-id}` classifies by severity and detects duplicates.

**Mid-sprint** — `/qa-dashboard --trend` for trends. If coverage drops or flaky tests rise, it's time to act.

**Sprint close** — `/testplan-results` consolidates results. This data feeds the executive report.

---

## How to talk to me

| You say... | I run... |
|---|---|
| "How's the quality?" | `/qa-dashboard` |
| "Generate a test plan" | `/testplan-generate` |
| "What tests does this PR need?" | `/qa-regression-plan --pr` |
| "Classify this bug" | `/qa-bug-triage {id}` |
| "Are there flaky tests?" | `/qa-dashboard --trend` |
| "Does the spec cover all cases?" | `/spec-verify {spec}` |

---

## Where your files are

```
output/
├── testplans/          ← generated test plans
├── test-results/       ← consolidated results
└── reports/            ← quality reports

.claude/
├── commands/
│   ├── qa-*.md         ← dashboard, regression, bug triage
│   ├── testplan-*.md   ← test plan generation and tracking
│   └── spec-verify*.md ← spec verification
├── skills/
│   └── coherence-check/ ← spec↔implementation coherence validation
└── rules/domain/
    └── eval-criteria.md ← evaluation criteria (type: code)
```

---

## How your work connects

SDD specs define the acceptance criteria you verify. When an agent implements, the tests it generates follow those criteria. Your `/qa-dashboard` aggregates coverage and escape rate, which feed DORA metrics (change failure rate). If a quality gate fails, it blocks the merge — the Tech Lead and PM see this. Your test plan results appear in the `/report-executive` that leadership receives.

---

## Next steps

- [Spec-Driven Development](../readme_en/05-sdd.md)
- [KPIs and rules](../readme_en/10-kpis-rules.md)
- [Data flow guide](../data-flow-guide-en.md)
- [Full commands](../readme/12-comandos-agentes.md)
