# Changelog

All notable changes to PM-Workspace are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- `backlog:capture` — create PBIs from unstructured input (emails, meeting notes, support tickets)
- `risk:log` — structured risk register updated automatically on each `/sprint:status`
- `sprint:release-notes` — auto-generate release notes combining work items + commits
- GitHub Actions: auto-label PRs by branch prefix (`feature/`, `fix/`, `docs/`)

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

[Unreleased]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/releases/tag/v0.1.0
