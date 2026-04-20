---
status: PROPOSED
---

# SPEC-SE-020 — Cross-Project Dependencies (Portfolio-as-Graph)

> **Priority:** P2 · **Estimate (human):** 7d · **Estimate (agent):** 7h · **Category:** complex · **Type:** portfolio coordination + dependency graph + resource contention + program management

## Objective

Give a 5000-person consultancy a **locally-computed, tenant-isolated portfolio intelligence layer** where cross-project dependencies live as `.md` declarations in each project, an agent builds a dependency graph across the tenant's entire project portfolio, computes the cross-project critical path, detects resource contention (same person on two critical paths), and surfaces dependency risks before they manifest as delivery failures.

PMI Pulse of the Profession 2024 reports that ~47% of program failures are caused by under-managed inter-project dependencies. Forrester data suggests organisations with PPM tools achieve 20–30% better resource utilization. The root cause: dependency information lives in people's heads, in Gantt charts that haven't been updated since kickoff, and in escalation emails that arrive too late.

Savia Enterprise makes dependencies explicit, versioned, and agent-queryable — computed locally from the `.md` files already present in each project, without uploading anything to a central PPM cloud.

## Principles affected

- **#1 Soberanía del dato** — dependency declarations are `.md` in each project. The portfolio graph is computed locally, never stored in a central SaaS.
- **#2 Independencia del proveedor** — no Planview/ServiceNow/Jira Align dependency. The graph is computed from plain YAML.
- **#4 Privacidad absoluta** — cross-project queries stay within the tenant boundary. No cross-tenant portfolio aggregation.
- **#5 El humano decide** — resource rebalancing recommendations are proposals. Humans decide.

## Design

### Dependency declaration per project

Each project declares its upstream and downstream dependencies in `deps.yaml`:

```yaml
# tenants/{tenant-id}/projects/{project-id}/deps.yaml
---
project: "erp-migration"
tenant: "acme-consulting"
dependencies:
  upstream:
    - project: "sso-integration"
      type: "blocks"           # blocks | feeds | shared-resource | shared-platform
      deliverable: "D-003"     # what this project needs from upstream (ref to SE-017 SOW)
      needed_by: "2026-07-15"  # date this project is blocked without it
      status: "on-track"       # on-track | at-risk | blocked | delivered
      contact: "@pm-sso"
    - project: "data-platform"
      type: "shared-platform"
      deliverable: "API v2"
      needed_by: "2026-08-01"
      status: "at-risk"
      contact: "@pm-data"
  downstream:
    - project: "mobile-app"
      type: "feeds"
      deliverable: "REST API spec"
      needed_by: "2026-09-01"
      contact: "@pm-mobile"
shared_resources:
  - person: "@architect-senior"
    projects: ["erp-migration", "sso-integration"]
    allocation_pct: [60, 40]
    conflict: false
  - person: "@dba-lead"
    projects: ["erp-migration", "data-platform", "mobile-app"]
    allocation_pct: [50, 30, 20]
    conflict: true   # >100% or on 2+ critical paths
---
```

### Portfolio graph (computed, not stored)

The `portfolio-grapher` agent reads all `deps.yaml` files across the tenant's projects and builds a dependency graph:

```
/portfolio-graph [--tenant X] [--format ascii|mermaid]

      ┌──────────────┐
      │ SSO Integ    │──────── API spec ──────►┌──────────────┐
      │ (on-track)   │                         │ Mobile App   │
      └──────┬───────┘                         │              │
             │ blocks D-003                    └──────────────┘
             ▼                                        ▲
      ┌──────────────┐                                │
      │ ERP Migrat   │──────── REST API spec ─────────┘
      │ (on-track)   │
      └──────┬───────┘
             │ shared-platform
             ▼
      ┌──────────────┐
      │ Data Platform│
      │ (at-risk) ⚠  │
      └──────────────┘
```

### Cross-project critical path

The `critical-path-analyzer` agent computes the critical path across all connected projects in the tenant:

```yaml
critical_path:
  - project: "data-platform"
    deliverable: "API v2"
    needed_by: "2026-08-01"
    status: "at-risk"
    slack_days: 0
  - project: "erp-migration"
    deliverable: "Data migration run-books"
    needed_by: "2026-09-15"
    depends_on: "data-platform:API v2"
    slack_days: 5
  - project: "mobile-app"
    deliverable: "Beta release"
    needed_by: "2026-10-01"
    depends_on: "erp-migration:REST API spec"
    slack_days: 10
total_path_length_days: 120
bottleneck: "data-platform (at-risk, 0 slack)"
```

### Resource contention detection

The `contention-detector` agent scans all `shared_resources` sections and flags:

1. **Critical-path collision**: same person assigned to 2+ projects on the critical path simultaneously.
2. **Over-allocation**: person's total allocation > 100% across projects.
3. **Bus-factor risk**: a person who is the sole expert on a critical-path deliverable.

```yaml
contention_alerts:
  - type: "over-allocation"
    person: "@dba-lead"
    total_allocation_pct: 100
    projects: ["erp-migration(50%)", "data-platform(30%)", "mobile-app(20%)"]
    recommendation: "Reduce mobile-app to 10%, bring in backup DBA"
  - type: "critical-path-collision"
    person: "@architect-senior"
    projects: ["erp-migration", "sso-integration"]
    critical_path: true
    recommendation: "Dedicate to erp-migration (critical) and assign backup to sso-integration"
```

### Rebalancing recommendations

The `rebalancer` agent produces human-reviewable recommendations:

```yaml
rebalance_proposal:
  generated: "2026-07-01"
  tenant: "acme-consulting"
  changes:
    - person: "@dba-lead"
      from: { "erp-migration": 50, "data-platform": 30, "mobile-app": 20 }
      to: { "erp-migration": 50, "data-platform": 40, "mobile-app": 10 }
      rationale: "data-platform is at-risk and on critical path"
    - person: "@qa-senior"
      from: { "erp-migration": 100 }
      to: { "erp-migration": 60, "mobile-app": 40 }
      rationale: "mobile-app needs QA coverage before beta; erp-migration QA load drops post-migration"
  impact:
    critical_path_change: "data-platform slack increases from 0 to 8 days"
    risk_reduction: "over-allocation resolved for @dba-lead"
  approved_by: null    # human fills
```

### New agents

| agent | level | purpose |
|-------|-------|---------|
| `portfolio-grapher` | L1 | Builds dependency graph from all projects' deps.yaml. Read-only. |
| `critical-path-analyzer` | L1 | Computes cross-project critical path and slack. |
| `contention-detector` | L1 | Flags resource over-allocation and critical-path collisions. |
| `rebalancer` | L1 | Proposes resource reallocation. Recommendations only — human approves. |

### New commands

| command | role | output |
|---------|------|--------|
| `/deps-declare PROJECT` | PM | Scaffolds/edits deps.yaml interactively. |
| `/portfolio-graph [--tenant X]` | portfolio-mgr | ASCII or Mermaid dependency graph. |
| `/portfolio-critical-path` | portfolio-mgr | Cross-project critical path analysis. |
| `/portfolio-contention` | resource-mgr | Resource contention alerts. |
| `/portfolio-rebalance` | resource-mgr | Rebalancing proposal (human approves). |
| `/deps-status PROJECT` | PM | Status of this project's upstream/downstream deps. |

### Events

```json
{"event": "deps.at_risk", "project": "data-platform", "deliverable": "API v2", "slack_days": 0}
{"event": "deps.blocked", "project": "erp-migration", "blocked_by": "data-platform:API v2"}
{"event": "deps.contention", "person": "@dba-lead", "total_pct": 100, "projects": 3}
{"event": "deps.rebalance_proposed", "changes": 2, "approved": false}
{"event": "deps.delivered", "project": "sso-integration", "deliverable": "D-003"}
```

## Acceptance criteria

1. Regla `docs/rules/domain/portfolio-as-graph.md` ≤150 lines.
2. JSON Schema for deps.yaml validates upstream/downstream/shared_resources.
3. `portfolio-grapher` correctly builds a graph from 5+ projects with interdependencies.
4. `/portfolio-graph` renders ASCII and Mermaid output.
5. `critical-path-analyzer` identifies the correct bottleneck in a 5-project test scenario.
6. `contention-detector` catches over-allocation >100% and critical-path collision.
7. `rebalancer` produces a proposal that resolves the contention in the test scenario.
8. `/deps-status` shows a project's upstream/downstream with live status (on-track/at-risk/blocked/delivered).
9. Events are emitted on status transitions (on-track→at-risk, at-risk→blocked, blocked→delivered).
10. 20+ BATS tests, SPEC-055 score ≥ 80.
11. Air-gap capable. `pr-plan` 11/11 gates.

## Out of scope

- Gantt chart rendering (ASCII table + Mermaid sufficient for v1).
- Automated resource allocation via optimization algorithm (proposals only).
- Multi-tenant cross-tenant dependency tracking (each tenant is isolated).
- Integration with resourcing tools (Float, Forecast, Runn) — adapter surface, not implemented.
- What-if scenario modeling (portfolio digital twin) — future enhancement.
- Program-level OKR alignment — acknowledged, not implemented in v1.
- Works council notification for EU bench allocation decisions (acknowledged, manual for v1).

## Dependencies

- **Blocked by:** SE-001, SE-002, SE-015 (pipeline provides demand forecast), SE-016 (valuation provides portfolio scoring), SE-017 (SOW deliverables are the dependency targets), SE-018 (billing provides cost actuals), SE-019 (evaluation provides quality signals).
- **Blocks:** nothing — SE-020 is the terminal node in the dependency chain.
- **Soft deps:** SE-014 (release coordination across projects may trigger deps.delivered events).

## Migration path

- Reversible: `CROSS_PROJECT_DEPS_ENABLED=false`.
- Import: `scripts/deps-import.sh` reads dependency data from Jira Align / MS Project XML.
- Coexistence: projects without `deps.yaml` are treated as independent (no upstream/downstream).

## Impact statement

Cross-project dependencies are the dark matter of programme management: invisible until they cause a failure, at which point the damage is already done. A system that makes dependencies explicit (each project declares what it needs and provides), computes the critical path across the portfolio, and surfaces resource contention before it blocks delivery converts the PMO from a reactive escalation desk to a proactive risk radar. For a consultancy running 50+ concurrent projects, catching one cross-project dependency failure per quarter is worth the entire engineering effort of this spec.

## Sources

- PMI Pulse of the Profession 2024 (dependency management statistics)
- PMI Standard for Program Management
- MSP (Managing Successful Programmes, UK Cabinet Office)
- ISO 21503:2017 Programme management guidance
- SAFe Lean Portfolio Management (ART coordination)
- Goldratt, Theory of Constraints / Critical Chain Project Management
- Forrester Research (PPM market sizing and utilization benchmarks)
- EU AI Act Article 14 (human oversight for high-risk AI decisions affecting workforce allocation)
