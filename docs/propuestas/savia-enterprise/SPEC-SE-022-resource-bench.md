# SPEC-SE-022 — Resource & Bench Management

> **Priority:** P1 · **Estimate (human):** 8d · **Estimate (agent):** 8h · **Category:** complex · **Type:** capacity planning + bench optimization + skills matching

## Objective

Give a 5000-person consultancy a **local, sovereign resource management
system** that tracks utilization in real time, optimizes bench allocation
with traceable decisions, matches people to projects by competency, and
surfaces capacity risks before they become delivery failures — all stored
as `.md` in the tenant's pm-workspace, with every allocation decision
auditable in git for EU AI Act compliance.

Bench utilization in Tier-1 consultancies targets 78-85%. Below 75%
triggers C-level escalation (cash burn). Above 90% causes burnout and
quality collapse. No PSA tool reliably predicts both directions. The root
cause: resource data lives in disconnected systems (ERP for HR, PSA for
projects, Excel for capacity planning, Teams for availability). By the
time a resource manager sees the full picture, the bench decision is
already stale.

Savia Enterprise makes resource allocation a versioned, agent-assisted
process where the data flows from project actuals (SE-018) and pipeline
demand (SE-015), and the decisions are transparent, auditable, and human-gated.

## Principles affected

- **#1 Soberanía del dato** — resource profiles and allocation history live as `.md` in the tenant repo, not in a SaaS PSA.
- **#4 Privacidad absoluta** — individual utilization data is N4b (PM-only). Aggregate data is N4 (project level).
- **#5 El humano decide** — allocation recommendations are proposals. Humans assign. The agent NEVER auto-assigns a person to a project.
- **#6 Igualdad** — skills-based matching applies Equality Shield counterfactual test. No gender/origin bias in recommendations.

## Design

### Resource profile structure

```
tenants/{tenant-id}/resources/
├── CAPACITY.md               # Tenant-wide capacity dashboard
├── profiles/
│   ├── {person-slug}.yaml    # One file per person
│   └── ...
├── allocations/
│   ├── {project-id}.yaml     # Current allocation per project
│   └── ...
├── bench/
│   ├── current.yaml          # Current bench list
│   └── history/              # Monthly snapshots
│       ├── 2026-04.yaml
│       └── ...
└── demand/
    ├── pipeline-demand.yaml  # Aggregated from SE-015 pursuits
    └── confirmed-demand.yaml # From SE-017 SOW commitments
```

### Person profile (resources/profiles/{slug}.yaml)

```yaml
---
person_id: "EMP-1234"
name_ref: "team/{slug}.md"     # N4b reference, not inline
role: "senior-developer"
practice: "cloud-migration"
location: "madrid"
availability_pct: 100          # 0-100, accounts for PTO/training
skills:
  - { skill: "dotnet", level: "expert", years: 8 }
  - { skill: "azure", level: "competent", years: 4 }
  - { skill: "terraform", level: "novice", years: 1 }
certifications: ["az-900", "az-204", "safe-practitioner"]
current_allocation:
  - { project: "erp-migration", pct: 60, role: "tech-lead", until: "2026-09-30" }
  - { project: "sso-integration", pct: 40, role: "developer", until: "2026-07-15" }
total_allocation_pct: 100
utilization_target_pct: 82
bench_since: null              # null = not on bench
last_project_end: "2026-03-15"
flight_risk: false             # PM assessment
---
```

### Utilization tracking

```yaml
# allocations/{project-id}.yaml
project: "erp-migration"
sow_ref: "definition/SOW.md"
team:
  - person: "EMP-1234"
    role: "tech-lead"
    allocation_pct: 60
    start: "2026-05-01"
    end: "2026-09-30"
    billable: true
  - person: "EMP-5678"
    role: "developer"
    allocation_pct: 100
    start: "2026-05-15"
    end: "2026-08-31"
    billable: true
total_fte: 1.6
budget_hours_month: 256
```

### Bench management

The `bench-tracker` agent computes bench status daily:

```yaml
# bench/current.yaml
as_of: "2026-04-12"
total_headcount: 342           # this practice
on_project: 285
on_bench: 57
utilization_pct: 83.3
target_range: [78, 85]
status: "optimal"              # under | optimal | over
alerts:
  - type: "over_bench"
    count: 12
    detail: "12 people on bench >30 days without assignment"
  - type: "flight_risk"
    count: 3
    detail: "3 bench members flagged as flight risk"
bench_list:
  - person: "EMP-9012"
    days_on_bench: 45
    skills: ["java", "spring", "aws"]
    match_score: 72            # highest match vs pipeline demand
    suggested_project: "OPP-2026-003"
```

### Skills-based matching

The `skills-matcher` agent cross-references bench profiles against
pipeline demand (SE-015) and confirmed SOW requirements (SE-017):

```yaml
match_results:
  - person: "EMP-9012"
    bench_days: 45
    candidates:
      - project: "OPP-2026-003"
        role_needed: "java-developer"
        match_score: 72
        skills_match: ["java:expert", "spring:competent"]
        skills_gap: ["kubernetes:novice needed"]
        action: "assign with 1-week ramp on k8s"
      - project: "OPP-2026-007"
        role_needed: "backend-developer"
        match_score: 58
        skills_match: ["java:expert"]
        skills_gap: ["go:competent needed"]
        action: "training required — 3 weeks"
    recommendation: "OPP-2026-003 — best fit with minimal ramp"
    equality_check: "counterfactual pass — same recommendation regardless of gender/origin"
```

### EU AI Act compliance for allocation decisions

Every allocation recommendation carries an audit record:

```yaml
allocation_decision:
  decision_id: "ALLOC-2026-0412-001"
  person: "EMP-9012"
  project: "OPP-2026-003"
  recommended_by: "skills-matcher"
  decided_by: "@resource-manager"       # ALWAYS human
  decision: "approved"
  rationale: "Best skills match, shortest bench tenure, no training gap"
  equality_shield:
    counterfactual_test: "pass"
    protected_attributes_considered: false
  ai_act_classification: "high-risk"    # HR allocation = high-risk per AI Act
  human_oversight: true
  traceable: true                       # git commit SHA
  timestamp: "2026-04-12T10:30:00Z"
```

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `bench-tracker` | L1 | Computes daily bench status, alerts on over-bench/flight-risk |
| `skills-matcher` | L1 | Matches bench profiles to pipeline demand, produces ranked candidates |
| `capacity-forecaster` | L1 | Projects utilization 4-8 weeks ahead from pipeline + confirmed demand |
| `allocation-auditor` | L1 | Verifies every allocation decision has human sign-off + equality check |

### New commands

| command | output |
|---------|--------|
| `/bench-status` | Current bench list with match scores |
| `/bench-match PERSON` | Top 3 project matches for a bench member |
| `/capacity-forecast [--weeks 8]` | Utilization projection with supply/demand gap |
| `/allocation-log [--person X]` | Audit trail of allocation decisions |
| `/utilization-dashboard` | Practice-wide utilization with zone indicators |

### Events

```json
{"event": "bench.person_added", "person": "EMP-9012", "practice": "cloud-migration"}
{"event": "bench.match_found", "person": "EMP-9012", "project": "OPP-2026-003", "score": 72}
{"event": "allocation.decided", "decision_id": "ALLOC-...", "decided_by": "@resource-manager"}
{"event": "utilization.zone_change", "practice": "cloud-migration", "from": "optimal", "to": "under"}
{"event": "capacity.gap_detected", "practice": "cloud-migration", "gap_fte": 3.2, "horizon_weeks": 6}
```

## Acceptance criteria

1. Regla `.claude/rules/domain/resource-bench.md` ≤150 lines.
2. Person profile YAML schema validates with 10+ required fields.
3. `bench-tracker` computes correct utilization % from allocation data.
4. `skills-matcher` produces ranked matches with equality shield check.
5. Every allocation decision record includes `decided_by` (human), `equality_shield`, and `ai_act_classification`.
6. `/capacity-forecast` projects 4-8 weeks with ±10% accuracy on test data.
7. Bench alerts fire when >30 days without assignment or flight_risk flagged.
8. Utilization zones (under/optimal/over) computed correctly from target range.
9. Pipeline demand (SE-015) feeds into confirmed demand (SE-017) automatically.
10. 20+ BATS tests, SPEC-055 ≥ 80.
11. Air-gap capable. `pr-plan` 11/11 gates.

## Out of scope

- HR system integration (Workday, SAP HCM, BambooHR) — adapter surface defined, not implemented.
- Payroll impact of allocation changes — finance territory.
- Performance reviews — N4b data, separate system.
- Training plan generation from skills gaps — future enhancement.
- Time tracking integration — SE-018 billing owns timesheets.
- Geo-restriction enforcement for regulated projects — acknowledged, manual for v1.

## Dependencies

- **Blocked by:** SE-001, SE-002, SE-015 (pipeline demand), SE-017 (SOW confirmed demand).
- **Integrates with:** SE-018 (billing uses allocation for chargeback), SE-020 (cross-project deps uses allocation for contention), SE-021 (Court uses allocation to assign fix tasks).
- **Soft deps:** SE-006 (governance for AI Act compliance), SE-019 (evaluation feeds skills assessment).

## Migration path

- Feature-flag `RESOURCE_BENCH_ENABLED=false`.
- Import: `scripts/resource-import.sh` reads CSV from HR/PSA export.
- Coexistence: projects without `resources/` directory skip all allocation logic.

## Impact statement

A consultancy with 342 people in a practice and 57 on the bench is
burning ~EUR 1.7M/month in unallocated capacity (at EUR 30K loaded
cost/person/month). Reducing bench from 57 to 45 — a 12-person
improvement — saves EUR 360K/month. A skills-matching agent that
surfaces the right match 2 days faster than manual search pays for
itself in the first week. The EU AI Act compliance audit trail is
the differentiator: no competing PSA tool produces git-versioned,
counterfactual-tested allocation evidence that satisfies Article 14.

## Sources

- SPI Research Professional Services Maturity Benchmark 2024
- EU AI Act (2024) — Article 14 (human oversight), Annex III (high-risk AI: employment)
- Gartner Magic Quadrant for Cloud HCM Suites 2025
- Float, Forecast, Runn, Kantata — resource management tool analysis
- PMI Pulse of the Profession 2024 (resource allocation challenges)
- Equality Shield (pm-workspace `.claude/rules/domain/equality-shield.md`)
