---
status: PROPOSED
---

# SPEC-SE-019 — Project Evaluation (Lessons-as-Code)

> **Priority:** P2 · **Estimate (human):** 5d · **Estimate (agent):** 5h · **Category:** standard · **Type:** post-delivery metrics + benefit realization + lessons learned + knowledge loop

## Objective

Give a 5000-person consultancy a **structured, agent-maintained post-delivery evaluation system** that closes the lifecycle loop from delivery back to prospecting by tracking benefit realization against the business case (SE-016), extracting reusable lessons from every project closure, computing quality metrics (CMMI-aligned), and feeding insights back into the proposal library (SE-015) so the next bid starts with intelligence from the last delivery.

PMI data shows organisations with formal lessons-learned processes have ~14% higher project success rates. McKinsey (2012, widely cited) found knowledge workers spend 19% of time searching for information. The root cause: lessons are written in Confluence at closure, never indexed, never queried, never surfaced at the moment of the next bid. Knowledge dies when the team disperses.

Savia Enterprise makes evaluation live code: structured `.md` with YAML frontmatter that agents can query across the tenant's entire project history.

## Principles affected

- **#1 Soberanía del dato** — evaluation data lives as `.md` in the tenant repo.
- **#4 Privacidad absoluta** — NPS scores, performance feedback, and lessons stay N4-isolated per project.
- **#5 El humano decide** — evaluation summaries are human-reviewed before sharing with clients or publishing to the library.

## Design

### Evaluation structure

```
tenants/{tenant-id}/projects/{project-id}/evaluation/
├── evaluation.md             # Master evaluation record (YAML frontmatter)
├── quality-metrics.yaml      # Delivery quality scores (CMMI-aligned)
├── nps-survey.yaml           # Client NPS + CSAT data
├── lessons-learned/
│   ├── LL-001-migration-tooling.md   # One lesson per file
│   ├── LL-002-stakeholder-alignment.md
│   └── ...
├── benefit-actuals.yaml      # Cross-reference to SE-016 benefit-actuals
└── closure-report.md         # Final project closure document
```

### Evaluation frontmatter

```yaml
---
eval_id: "EVAL-2026-001"
tenant: "acme-consulting"
project: "erp-migration"
sow_id: "acme-erp-migration-2026"
case_id: "BC-2026-001"
status: "in-progress"    # not-started | in-progress | completed | archived
delivery_start: "2026-05-01"
delivery_end: "2026-10-31"
closure_date: null
quality_score: null       # computed from quality-metrics.yaml
nps_score: null           # from nps-survey.yaml
lessons_count: 0
benefit_realization_pct: null  # from SE-016 review cycle
overall_rating: null      # computed: weighted(quality, nps, benefit, budget)
budget_performance:
  planned_eur: 420000
  actual_eur: null
  variance_pct: null
team_satisfaction_score: null  # internal team feedback
library_contributions: 0  # lessons pushed to SE-015 library
---
```

### Quality metrics (CMMI-aligned)

```yaml
metrics:
  scope:
    deliverables_planned: 5
    deliverables_accepted: 4
    acceptance_rate_pct: 80
    scope_changes: 2
  schedule:
    milestones_planned: 8
    milestones_on_time: 6
    schedule_performance_index: 0.89
  defects:
    defects_found: 12
    defects_resolved: 11
    escape_rate_pct: 8    # defects found post-acceptance
  process:
    retrospectives_held: 5
    action_items_completed_pct: 72
    cmmi_compliance_score: 3.2  # 1-5 scale
  team:
    utilization_pct: 82
    rework_pct: 8
    knowledge_transfer_sessions: 3
```

### NPS / CSAT collection

```yaml
survey:
  type: "nps"
  sent_date: "2026-11-05"
  response_date: "2026-11-12"
  respondent_role: "client_engagement_authority"
  nps_score: 8     # 0-10
  nps_category: "passive"   # detractor (0-6) | passive (7-8) | promoter (9-10)
  csat_dimensions:
    - { dimension: "technical_quality", score: 4, max: 5 }
    - { dimension: "communication", score: 3, max: 5 }
    - { dimension: "timeliness", score: 4, max: 5 }
    - { dimension: "value_for_money", score: 4, max: 5 }
  open_feedback: "Migration went well. Communication could improve during UAT."
```

### Lessons learned — structured and queryable

Each lesson is a separate `.md` file with YAML frontmatter:

```yaml
---
lesson_id: "LL-001"
project: "erp-migration"
category: "tooling"    # tooling | process | people | technical | commercial | risk
severity: "medium"     # low | medium | high | critical
title: "Custom migration scripts outperformed vendor ETL tool"
applicable_to: ["data-migration", "erp", "legacy-modernization"]  # tags for retrieval
reusable: true
library_pushed: false
---

## What happened
Vendor ETL tool could not handle custom ABAP table structures. Team built
custom Python scripts that ran 3x faster with better error handling.

## Root cause
Vendor tool assumed standard SAP schema. 80% of tables were customized.

## Recommendation
For SAP migrations with >50% custom tables, budget for custom tooling
from sprint 2. Do not assume vendor ETL covers edge cases.

## Evidence
- Sprint retro 3 (2026-07-15): "ETL tool failed on 12 of 30 tables"
- Timesheet delta: 120h saved vs re-estimate
```

### Knowledge loop: evaluation → library → next bid

The `knowledge-feeder` agent reads `lessons-learned/*.md` tagged `reusable: true` and pushes sanitized versions to the tenant's proposal library (`pipeline/library/case-studies/` from SE-015). This closes the loop:

```
SE-015 bid → SE-017 SOW → delivery → SE-019 evaluation
    ↑                                        │
    └────────── lessons → library ───────────┘
```

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `evaluation-compiler` | L1 | On project closure, aggregates quality metrics, benefit actuals, NPS, lessons into evaluation.md. |
| `knowledge-feeder` | L2 | Sanitizes reusable lessons and pushes to SE-015 proposal library as case-study entries. |
| `closure-generator` | L2 | Generates closure-report.md from all evaluation artifacts + SE-016 benefit reviews. |
| `cross-eval-analyst` | L1 | Mines patterns across multiple project evaluations in the same tenant (e.g., "data migration projects consistently overrun by 20%"). |

### New commands

| command | role | output |
|---------|------|--------|
| `/eval-init PROJECT` | engagement-mgr | Scaffolds `evaluation/` directory from project data. |
| `/eval-close PROJECT` | engagement-mgr | Runs `evaluation-compiler` + `closure-generator`. |
| `/eval-nps PROJECT` | account-exec | Generates NPS survey template and records response. |
| `/eval-lessons PROJECT` | anyone | Lists lessons with filters (category, severity, tags). |
| `/eval-push-library LL-001` | practice-leader | Approves and pushes a lesson to the proposal library. |
| `/eval-cross-pattern [--tenant X]` | portfolio-mgr | Runs `cross-eval-analyst` across completed projects. |

### Events

```json
{"event": "eval.closed", "eval_id": "...", "quality_score": 3.2, "nps": 8}
{"event": "eval.lesson_created", "lesson_id": "LL-001", "category": "tooling"}
{"event": "eval.lesson_pushed_to_library", "lesson_id": "LL-001", "target": "pipeline/library/case-studies/"}
{"event": "eval.cross_pattern_found", "pattern": "data-migration overrun", "affected_projects": 3}
```

## Acceptance criteria

1. Regla `docs/rules/domain/lessons-as-code.md` ≤150 lines.
2. JSON Schema for evaluation.md + lesson frontmatter.
3. `/eval-close` produces a closure-report.md that passes schema validation.
4. NPS survey template covers the 4 CSAT dimensions.
5. `knowledge-feeder` sanitizes lesson text (removes project-specific identifiers) before pushing to library.
6. `cross-eval-analyst` detects a synthetic pattern across 3+ project evaluations.
7. Lessons are queryable by category + tags via `/eval-lessons --tag data-migration`.
8. Knowledge loop proven: a lesson from project A appears in the library and is findable by the proposal-drafter in SE-015.
9. 20+ BATS tests, SPEC-055 score ≥ 80.
10. Air-gap capable. `pr-plan` 11/11 gates.

## Out of scope

- 360-degree performance reviews of individual team members (HR system territory).
- Automated NPS outreach to clients (manual send for v1).
- Competitive intelligence from lost-bid postmortems (acknowledged, not implemented).
- Predictive modeling from lessons corpus (future ML enhancement).
- Integration with survey platforms (Qualtrics / SurveyMonkey) — manual data entry for v1.

## Dependencies

- **Blocked by:** SE-001, SE-002, SE-014 (release history as evaluation baseline), SE-016 (benefit actuals), SE-017 (SOW deliverables as acceptance baseline).
- **Blocks:** SE-020 (cross-project evaluation patterns feed portfolio intelligence).
- **Soft deps:** SE-015 (library — target for knowledge-feeder output), SE-018 (billing actuals for budget performance).

## Migration path

- Reversible: `EVALUATION_ENABLED=false`.
- Import: `scripts/eval-import.sh` reads lessons from Confluence/SharePoint export.
- Coexistence: projects without `evaluation/` skip all evaluation logic.

## Impact statement

The knowledge loop is the most valuable capability in the entire SE-014..SE-020 suite, and it costs almost nothing to operate. A lesson extracted from one project and surfaced during the next bid prevents the same mistake from being repeated across 200+ active engagements. The compound value of systematic knowledge reuse at consultancy scale is the difference between a 30% win rate and a 45% win rate — worth millions annually.

## Sources

- CMMI Institute Model for Services/Development
- PMI Pulse of the Profession (lessons learned statistics)
- PRINCE2 End Project Report + Lessons Report templates
- ISO 21502:2020 clause on project closure
- Net Promoter System (Bain / Reichheld)
- McKinsey Global Institute (knowledge worker time allocation)
