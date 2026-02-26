# Changelog

All notable changes to PM-Workspace are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned for v0.3.0
- `backlog:capture` — create PBIs from unstructured input (emails, meeting notes, support tickets)
- `risk:log` — structured risk register updated automatically on each `/sprint:status`
- `sprint:release-notes` — auto-generate release notes combining work items + commits
- GitHub Actions: auto-label PRs by branch prefix (`feature/`, `fix/`, `docs/`)

---

## [0.2.0] — 2026-02-26

Quality, discovery, and operations expansion. Adds 6 new slash commands, 1 new skill, enhances 2 existing agents, and aligns all documentation.

### Added

**Product Discovery workflow**
- `/pbi:jtbd {id}` — generate Jobs to be Done document for a PBI before technical decomposition
- `/pbi:prd {id}` — generate Product Requirements Document (MoSCoW prioritisation, Gherkin acceptance criteria, risks)
- `product-discovery` skill (`.claude/skills/product-discovery/`) with JTBD and PRD reference templates

**Quality and operations commands**
- `/pr:review [PR]` — multi-perspective PR review from 5 angles: Business Analyst, Developer, QA Engineer, Security, DevOps
- `/context:load` — session initialisation: loads CLAUDE.md, checks git branches, summarises recent commits, verifies tools
- `/changelog:update` — automates CHANGELOG.md updates from conventional commits with semantic version suggestion
- `/evaluate:repo [URL]` — static security and quality evaluation of external repositories before adoption (6 criteria + Claude Code-specific checklist)

**Agents and rules enhancements**
- `security-guardian` — new SEC-8: merge conflict markers and git artifacts detection (`.orig`, `.BACKUP`, `.BASE`, `.LOCAL`, `.REMOTE`)
- `commit-guardian` — new CHECK 9: commit atomicity verification (signals: >3 unrelated root dirs, disparate file types, >300 lines diff; exceptions: related command+docs, fix+test, same-module refactor)
- `csharp-rules.md` — knowledge base with 70+ static analysis rules equivalent to SonarQube (Vulnerabilities, Security Hotspots, Bugs, Code Smells) + 12 Clean Architecture/DDD rules (ARCH-01 to ARCH-12)
- `test-runner` agent — post-commit test execution, coverage verification, improvement orchestration
- `CLAUDE_MODEL_MID` — new constant for mid-tier model (Sonnet)

### Changed
- Models upgraded to generation 4.6: Opus `claude-opus-4-6`, Sonnet `claude-sonnet-4-6` (Haiku 4.5 maintained)
- `commit-guardian` expanded from 8 to 10 checks — CHECK 6 (Code Review with auto-correction cycle) and CHECK 9 (atomicity)
- `security-guardian` expanded from 8 to 9 checks — SEC-8 (merge conflict markers)
- `code-reviewer` now references `csharp-rules.md` and cites rule IDs in each finding
- `business-analyst` agent now covers JTBD and PRD generation
- Updated all agent, config, skill, command, and project CLAUDE.md files with new model IDs
- Workspace totals: 19 → 24 commands, 7 → 8 skills, 9 → 11 agents
- `README.md`, `README.en.md`, `.claude/README.md`, `CLAUDE.md`, `pm-workflow.md` aligned with new counts and capabilities
- `github-flow.md` updated with branch naming conventions and main-return rules

---

## [0.1.0] — 2026-03-01

Initial public release of PM-Workspace.

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

[Unreleased]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/releases/tag/v0.1.0
