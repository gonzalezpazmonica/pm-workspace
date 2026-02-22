# Changelog

All notable changes to PM Workspace are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned for v0.2.0
- `backlog:capture` — create PBIs from unstructured input (emails, meeting notes, support tickets)
- `risk:log` — structured risk register updated automatically on each `/sprint:status`
- `sprint:release-notes` — auto-generate release notes from completed items and commits
- `/pr:status` — track pull request state (reviewers, pending comments, time in review)
- GitHub Actions: auto-label PRs by branch prefix (`feature/`, `fix/`, `docs/`)

---

## [0.1.0] — 2026-03-01

Initial public release of PM Workspace.

### Added

**Core workspace**
- `CLAUDE.md` — global entry point with org constants, project registry, and tool definitions
- `SETUP.md` — step-by-step setup guide (PAT, constants, npm install, git clone, first run)
- Project template structure: `CLAUDE.md`, `equipo.md`, `reglas-negocio.md`, `sprints/`, `specs/`

**Sprint management commands** (`.claude/commands/`)
- `/sprint:status` — burndown, active items, WIP alerts, blocker detection, capacity remaining
- `/sprint:plan` — sprint planning assistant: real capacity calculation + PBI candidate selection
- `/sprint:review` — sprint review summary: velocity, completed items, demo preparation
- `/sprint:retro` — retrospective with quantitative sprint data (what went well / improve)

**Reporting commands**
- `/report:hours` — timesheet report (Excel, 4 tabs) from Azure DevOps data
- `/report:executive` — multi-project executive report (PPT + Word with traffic lights)
- `/report:capacity` — weekly team capacity status
- `/team:workload` — per-person workload map with overload alerts
- `/board:flow` — cycle time and bottleneck analysis
- `/kpi:dashboard` — full KPI dashboard: velocity, cycle time, lead time, bug escape rate

**PBI decomposition commands**
- `/pbi:decompose` — decompose a single PBI into tasks with hours, activity, assignee, and Developer Type
- `/pbi:decompose-batch` — decompose multiple PBIs in a single session
- `/pbi:assign` — (re)assign tasks for a PBI using the scoring algorithm
- `/pbi:plan-sprint` — full sprint planning cycle: capacity → PBI selection → decomposition → assignment → AzDO creation

**Skills** (`.claude/skills/`)
- `azure-devops-queries` — WIQL queries, REST API v7.1, Analytics OData
- `sprint-management` — burndown calculation, WIP limits, velocity tracking
- `capacity-planning` — capacity formula (`working_days × hours_day × focus_factor`), scoring algorithm
- `time-tracking-report` — Excel/PPT generation from AzDO time entries
- `executive-reporting` — multi-project Word + PowerPoint report generation
- `pbi-decomposition` — task breakdown by activity type, assignment scoring reference

**Spec-Driven Development (SDD)**
- `/spec:generate` — generate `.spec.md` contract from Azure DevOps task
- `/spec:implement` — implement spec (routes to human or launches Claude agent)
- `/spec:review` — validate spec quality or post-implementation correctness
- `/spec:status` — sprint-wide SDD dashboard with per-spec status and cost tracking
- `/agent:run` — launch Claude agent (single, team, or batch) against a spec file
- `spec-driven-development` skill with three references:
  - `spec-template.md` — 9-section spec template
  - `layer-assignment-matrix.md` — Clean Architecture layer → human vs. agent matrix
  - `agent-team-patterns.md` — five agent team patterns (single, impl-test, impl-test-review, full-stack, parallel-handlers)

**Test project** (`projects/sala-reservas/`)
- Full simulated project: meeting room booking app (.NET 8, Clean Architecture, CQRS/MediatR)
- Team: 4 human developers + PM + Claude agent team
- 16 documented business rules (RN-SALA, RN-RESERVA)
- Sprint planning with 3 PBIs (11 SP), complete with task breakdown and Developer Type assignments
- 2 complete SDD spec files ready to run against a real agent
- Mock Azure DevOps data: `mock-workitems.json`, `mock-sprint.json`, `mock-capacities.json`

**Test suite** (`scripts/test-workspace.sh`)
- 96 tests across 9 categories: prereqs, structure, connection, capacity, sprint, imputacion, sdd, report, backlog
- Mock mode (`--mock`) and real mode (`--real`)
- `--only {category}` flag for targeted runs
- `--verbose` flag for detailed output
- Automatic Markdown report in `output/`

**Documentation**
- `README.md` — comprehensive guide with 9 annotated real-usage examples
- `docs/reglas-scrum.md` — Scrum rules and definitions
- `docs/politica-estimacion.md` — estimation policy and Story Point reference
- `docs/kpis-equipo.md` — KPI definitions and thresholds
- `docs/plantillas-informes.md` — report template specifications
- `docs/flujo-trabajo.md` — full workflow guide including SDD section

---

[Unreleased]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/releases/tag/v0.1.0
