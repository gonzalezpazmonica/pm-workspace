# Changelog

All notable changes to PM-Workspace are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned

**High priority — Project Onboarding & Release Planning pipeline**

Full automated workflow for onboarding new projects and planning their execution. Five interconnected phases:

- `project:audit` — (Phase 1: Analysis) Deep audit of a newly onboarded project: code quality, architecture, test coverage, technical debt, security, documentation, CI/CD maturity. Generates a prioritized action report with three tiers: critical (must fix), improvable (should fix), and good (keep). Leverages `/evaluate:repo`, `/sentry:health`, `/pipeline:status`, `/debt:track`, and `/kpi:dora` internally. Output: `output/audits/YYYYMMDD-audit-{project}.md`
- `project:release-plan` — (Phase 2: Planning) Generate a prioritized release plan from the audit report + backlog. Groups PBIs into logical releases respecting dependencies (`/dependency:map`), risk (`/risk:log`), and business value. Each release has: scope, entry/exit criteria, estimated sprints, and dependency graph. Supports both greenfield and legacy projects (strangler fig phasing for legacy). Output: `output/plans/YYYYMMDD-release-plan-{project}.md`
- `project:assign` — (Phase 3: Assignment) Distribute release plan work across the team. Reads `equipo.md` profiles (skills, seniority, capacity), applies `/team:workload` and `/report:capacity` to balance load, and assigns PBIs/Tasks per sprint using the scoring algorithm from `pbi-decomposition` skill. Generates assignment matrix with per-person load, skill-match %, and overload alerts
- `project:roadmap` — (Phase 4: Roadmap) Generate a visual roadmap from the release plan: timeline with milestones, releases, sprints, and dependencies. Uses `/diagram:generate` to produce Mermaid gantt/flow → Draw.io or Miro. Also generates an executive-friendly summary via `/report:executive`. Output: diagram + `output/roadmaps/YYYYMMDD-roadmap-{project}.md`
- `project:kickoff` — (Phase 5: Notification) Summarize and notify. Compiles audit + release plan + assignments + roadmap into a kickoff report. Sends to PM and stakeholders via configured channel (`/notify:slack`, email, or Teams). Creates the Sprint 1 backlog in Azure DevOps with the first release scope already decomposed and assigned

**High priority — industry consensus, clear gap in pm-workspace**
- `legacy:assess` — legacy application assessment: complexity score, maintenance cost, risk rating, modernization roadmap (strangler fig pattern). Feeds into `project:audit` and `project:release-plan` for legacy onboarding

**Medium priority — valuable additions aligned with current architecture**
- `backlog:capture` — create PBIs from unstructured input (emails, meeting notes, support tickets)
- `sprint:release-notes` — auto-generate release notes combining work items + commits
- `wiki:publish` / `wiki:sync` — publish and sync documentation with Azure DevOps Wiki (MCP has 6 wiki tools)
- `testplan:status` / `testplan:results` — manage Azure DevOps Test Plans and view test results (MCP has 9 test plan tools)
- `security:alerts` — surface security alerts from Azure DevOps Advanced Security (MCP has 2 security tools)

**Lower priority — infrastructure and tooling**
- GitHub Actions: auto-label PRs by branch prefix (`feature/`, `fix/`, `docs/`)
- Migrate work item CRUD from REST/CLI (`azdevops-queries.sh`) to MCP tools where equivalent

---

## [0.5.0] — 2026-02-27

Governance foundations: technical debt tracking, DORA metrics, dependency mapping, retrospective action follow-up, and risk management. Adds 5 new governance commands. Total: 62 slash commands.

### Added

**Governance commands (5)** — PR #40
- `/debt:track --project {p}` — technical debt register: debt ratio, trend per sprint, SonarQube integration. Stores data in `projects/{p}/debt-register.md`
- `/kpi:dora --project {p}` — DORA metrics dashboard: deployment frequency, lead time, change failure rate, MTTR. Classifies as Elite/High/Medium/Low per DORA 2025 benchmarks
- `/dependency:map --project {p}` — cross-team/cross-PBI dependency mapping with blocking alerts, circular dependency detection, critical path analysis. Visual graph via `/diagram:generate`
- `/retro:actions --project {p}` — retrospective action items tracking: ownership, status, % implementation across sprints. Detects recurrent themes and suggests elevation to initiatives
- `/risk:log --project {p}` — risk register: probability × impact matrix (1-3 scale), exposure scoring, risk burndown chart. Stores in `projects/{p}/risk-register.md`

### Changed
- Command count: 57 → 62 (+5 governance)
- Help command updated with Governance (5) category
- `pm-workflow.md` updated with 5 new governance command entries
- READMEs (ES/EN) updated with governance commands

---

## [0.4.0] — 2026-02-27

Connectors ecosystem, Azure DevOps MCP optimization, CI/CD pipelines, and Azure Repos management. Adds 8 connector integrations (23 commands), 5 pipeline commands, 6 Azure Repos commands, 1 new skill, and 1 new config rule. Total: 57 slash commands, 12 skills.

### Added

**Connector integrations (8 connectors, 12 commands)** — PRs #27–#34
- `/notify:slack {canal} {msg}` — send notifications and reports to Slack channels
- `/slack:search {query}` — search messages and decisions in Slack for context
- `/github:activity {repo}` — analyze GitHub activity: PRs, commits, contributors
- `/github:issues {repo}` — manage GitHub issues: search, create, sync with Azure DevOps
- `/sentry:health --project {p}` — health metrics from Sentry: error rate, crash rate, p95 latency
- `/sentry:bugs --project {p}` — create Bug PBIs in Azure DevOps from frequent Sentry errors
- `/gdrive:upload {file} --project {p}` — upload generated reports and documents to Google Drive
- `/linear:sync --project {p}` — bidirectional sync Linear issues ↔ Azure DevOps PBIs/Tasks
- `/jira:sync --project {p}` — bidirectional sync Jira issues ↔ Azure DevOps PBIs
- `/confluence:publish {file} --project {p}` — publish documentation and reports to Confluence
- `/notion:sync --project {p}` — bidirectional document sync with Notion databases
- `/figma:extract {url} --project {p}` — extract UI components, screens, and design tokens from Figma
- `connectors-config.md` — centralized connector configuration with per-connector enable/disable

**Azure Pipelines CI/CD (5 commands, 1 skill)** — PR #35
- `/pipeline:status --project {p}` — pipeline health: last builds, success rate, duration, alerts
- `/pipeline:run --project {p} {pipeline}` — execute pipeline with preview and PM confirmation
- `/pipeline:logs --project {p} --build {id}` — build logs: timeline, errors, warnings
- `/pipeline:create --project {p} --name {n}` — create pipeline from YAML templates with preview
- `/pipeline:artifacts --project {p} --build {id}` — list/download build artifacts
- `azure-pipelines` skill with YAML templates (build+test, multi-env, PR validation, nightly) and stage patterns (DEV→PRE→PRO with approval gates)

**Azure Repos management (6 commands, 1 config rule)** — PR #36
- `/repos:list --project {p}` — list Azure DevOps repositories with stats
- `/repos:branches --project {p} --repo {r}` — branch management: list, create, compare
- `/repos:pr-create --project {p} --repo {r}` — create PR with work item linking, reviewers, auto-complete
- `/repos:pr-list --project {p}` — list PRs: pending, assigned to PM, by reviewer
- `/repos:pr-review --project {p} --pr {id}` — multi-perspective PR review (BA, Dev, QA, Security, DevOps)
- `/repos:search --project {p} {query}` — search code across Azure Repos
- `azure-repos-config.md` — dual Git provider support (`GIT_PROVIDER = "github" | "azure-repos"` per project)

**DevOps workflow improvements** — PR #26
- Task ID in branch names: `feature/#XXXX-descripcion`
- Auto-reviewer assignment on PR creation
- PM notification filter for relevant updates

### Changed
- PAT scopes expanded: `Code R/W`, `Build R/W`, `Release R` (for pipeline and repo operations)
- Command count: 46 → 57 (+5 pipeline, +6 repos, no net change from connectors already counted in 0.3.0 changelog)
- Skills count: 11 → 12 (+azure-pipelines)
- Help command updated with Pipelines (5) and Azure Repos (6) categories
- `pm-workflow.md` updated with 11 new command entries
- READMEs (ES/EN) updated with new commands, skill, and rule entries
- GitHub CLI (`gh`) added as workspace dependency in SETUP.md

---

## [0.3.0] — 2026-02-26

Multi-language, multi-environment, infrastructure as code, documentation reorganization, and file size governance. Adds 16 Language Packs, 7 new commands, 1 new agent, 12 new developer agents, and a 150-line file size rule.

### Added

**Multi-language support (16 Language Packs)**
- Per-language conventions, rules, developer agents, and layer matrices for: C#/.NET, TypeScript/Node.js, Angular, React, Java/Spring Boot, Python, Go, Rust, PHP/Laravel, Swift/iOS, Kotlin/Android, Ruby/Rails, VB.NET, COBOL, Terraform/IaC, Flutter/Dart
- 12 new developer agents: `typescript-developer`, `frontend-developer`, `java-developer`, `python-developer`, `go-developer`, `rust-developer`, `php-developer`, `mobile-developer`, `ruby-developer`, `cobol-developer`, `terraform-developer`, `infrastructure-agent`
- `language-packs.md` — centralized Language Pack catalog with auto-detection table
- `agents-catalog.md` — centralized agent catalog with flow diagrams
- `docs/guia-incorporacion-lenguajes.md` — step-by-step guide for adding new languages

**Multi-environment and Infrastructure as Code**
- `environment-config.md` — configurable multi-environment system (DEV/PRE/PRO by default, customizable names and counts)
- `confidentiality-config.md` — secrets protection policy (Key Vault, SSM, Secret Manager, config.local/)
- `infrastructure-as-code.md` — multi-cloud IaC support (Terraform, Azure CLI, AWS CLI, GCP CLI, Bicep, CDK, Pulumi)
- `infrastructure-agent` (Opus 4.6) — auto-detect existing resources, minimum viable tier, cost estimation, human approval for scaling
- 7 new commands: `/infra:detect`, `/infra:plan`, `/infra:estimate`, `/infra:scale`, `/infra:status`, `/env:setup`, `/env:promote`

**File size governance**
- `file-size-limit.md` — max 150 lines per file (code, rules, docs, tests); legacy inherited code exempt unless PM requests refactor

**Team evaluation and onboarding**
- `/team:evaluate` — competency evaluation across 8 dimensions with radar charts
- `business-analyst` agent extended with onboarding and GDPR-compliant evaluation capabilities
- Onboarding proposal and evaluation framework in `docs/propuestas/`

### Changed
- README.md and README.en.md split into 12 sections each under `docs/readme/` and `docs/readme_en/`; root READMEs now serve as compact hub documents (~130 lines)
- Documentation moved from root to `docs/`: ADOPTION_GUIDE, SETUP, ROADMAP, proposals, .docx guides
- CLAUDE.md compacted from 217 to 127 lines; agent and language tables externalized to dedicated rule files
- Workspace totals: 24 → 35 commands, 11 → 23 agents, 8 → 9 skills
- All .NET-only references updated to multi-language throughout documentation
- Cross-references updated across 6 files after reorganization

---

## [0.2.0] — 2026-02-26

Quality, discovery, and operations expansion. Adds 6 new slash commands, 1 new skill, enhances 2 existing agents, and aligns all documentation.

### Added

**Product Discovery workflow**
- `/pbi:jtbd {id}` — generate Jobs to be Done document for a PBI before technical decomposition
- `/pbi:prd {id}` — generate Product Requirements Document (MoSCoW prioritisation, Gherkin acceptance criteria, risks)
- `product-discovery` skill with JTBD and PRD reference templates

**Quality and operations commands**
- `/pr:review [PR]` — multi-perspective PR review from 5 angles
- `/context:load` — session initialisation: loads CLAUDE.md, checks git, summarises commits, verifies tools
- `/changelog:update` — automates CHANGELOG.md updates from conventional commits
- `/evaluate:repo [URL]` — static security and quality evaluation of external repositories

**Agents and rules enhancements**
- `security-guardian` — SEC-8: merge conflict markers detection
- `commit-guardian` — CHECK 9: commit atomicity verification
- `csharp-rules.md` — 70+ static analysis rules + 12 Clean Architecture/DDD rules
- `test-runner` agent — post-commit test execution and coverage orchestration
- `CLAUDE_MODEL_MID` — new constant for mid-tier model (Sonnet)

### Changed
- Models upgraded to generation 4.6: Opus `claude-opus-4-6`, Sonnet `claude-sonnet-4-6`
- `commit-guardian` expanded from 8 to 10 checks
- `security-guardian` expanded from 8 to 9 checks
- Workspace totals: 19 → 24 commands, 7 → 8 skills, 9 → 11 agents

---

## [0.1.0] — 2026-03-01

Initial public release of PM-Workspace.

### Added

**Core workspace**
- `CLAUDE.md` — global entry point with org constants, project registry, and tool definitions
- `docs/SETUP.md` — step-by-step setup guide

**Sprint management commands**
- `/sprint:status`, `/sprint:plan`, `/sprint:review`, `/sprint:retro`

**Reporting commands**
- `/report:hours`, `/report:executive`, `/report:capacity`
- `/team:workload`, `/board:flow`, `/kpi:dashboard`

**PBI decomposition commands**
- `/pbi:decompose`, `/pbi:decompose-batch`, `/pbi:assign`, `/pbi:plan-sprint`

**Skills**
- `azure-devops-queries`, `sprint-management`, `capacity-planning`
- `time-tracking-report`, `executive-reporting`, `pbi-decomposition`

**Spec-Driven Development (SDD)**
- `/spec:generate`, `/spec:implement`, `/spec:review`, `/spec:status`, `/agent:run`
- `spec-driven-development` skill with spec template, layer matrix, agent patterns

**Test project** (`projects/sala-reservas/`)
- Meeting room booking app (.NET 8, Clean Architecture, CQRS/MediatR)
- 16 business rules, 3 PBIs, 2 complete SDD specs

**Test suite** (`scripts/test-workspace.sh`)
- 96 tests across 9 categories with mock and real modes

**Documentation**
- `README.md` with 9 annotated examples
- `docs/` methodology: Scrum rules, estimation policy, KPIs, report templates, workflow guide

---

[Unreleased]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/releases/tag/v0.1.0
