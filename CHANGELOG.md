# Changelog

All notable changes to PM-Workspace are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

*No planned items — all features from the original roadmap have been implemented.*

---

## [0.12.0] — 2026-02-27

Context optimization: 58% reduction in auto-loaded context. Domain-specific rules moved to on-demand loading, freeing ~1,200 lines of context window for actual PM work. Prevents context saturation that caused commands to fail silently at high usage.

### Changed

**Context architecture overhaul**
- Created `rules/domain/` subdirectory for domain-specific rules (excluded from auto-loading via `.claudeignore`)
- 8 rules moved from auto-load to on-demand: `infrastructure-as-code.md` (289 lines), `confidentiality-config.md` (274), `messaging-config.md` (238), `environment-config.md` (186), `mcp-migration.md` (72), `connectors-config.md` (66), `azure-repos-config.md` (52), `diagram-config.md` (50)
- Auto-loaded context reduced from 2,109 lines to 882 lines (-58%)
- 10 core rules remain auto-loaded: pm-config, pm-workflow, github-flow, command-ux-feedback, command-validation, file-size-limit, readme-update, language-packs, agents-catalog, pm-config.local
- Commands that need domain rules now reference them explicitly with `@.claude/rules/domain/` path
- `.claudeignore` updated to exclude `rules/domain/` alongside existing `rules/languages/` exclusion

**References updated across 17 files:**
- CLAUDE.md: 4 rule references updated to `domain/` path
- 6 messaging commands: messaging-config reference updated
- 4 Azure Repos commands: azure-repos-config reference updated
- 1 skill (azure-pipelines): environment-config reference updated
- pm-workflow.md: 8 references updated
- docs (ES/EN): structure trees updated showing auto-loaded vs on-demand

---

## [0.11.0] — 2026-02-27

UX Feedback Standards: Every command now provides consistent visual feedback — start banners, progress indicators, error handling with interactive recovery, and end banners. The PM always knows what's happening. Interactive setup mode in `/help --setup` guides through configuration step by step.

### Added

**UX Feedback rule** — `command-ux-feedback.md`
- Mandatory feedback standards for ALL commands (start banner, progress, errors, end banner)
- Interactive prerequisite resolution: missing config → ask PM → save → retry automatically
- Progress indicators for multi-step commands (`📋 Paso 1/N — Descripción...`)
- Three completion states: success (`✅`), partial (`⚠️`), error (`❌`)
- Automatic retry after interactive configuration — PM never re-types the command

### Changed

**`/help` rewritten with interactive setup mode**
- Shows `✅`/`❌` per configuration check with clear explanations
- For each missing item: explains why it's needed, asks for the value interactively, saves it, confirms
- After resolving all issues, re-verifies and shows updated status
- Retry flow: fail → ask → save → retry → show result

**6 core commands updated with UX feedback pattern:**
- `/sprint:status` — banners, prerequisite checks, progress steps, completion summary
- `/project:audit` — banners, interactive project creation if missing, 5-step progress, detailed completion
- `/evaluate:repo` — banners, clone verification, 5-step progress, score summary
- `/debt:track` — banners, parameter validation, 3-step progress, debt ratio summary
- `/kpi:dora` — banners, prerequisite checks, 4-step progress, performer classification
- `/context:load` — banners, 5-step progress, session summary

**Documentation updated:**
- `pm-workflow.md` — added UX Feedback reference
- `docs/readme/02-estructura.md` — added `command-ux-feedback.md` to rules tree
- `docs/readme_en/02-structure.md` — same update (EN)

---

## [0.10.0] — 2026-02-27

Infrastructure and tooling: GitHub Actions workflow for auto-labeling PRs, and MCP migration guide documenting which `azdevops-queries.sh` functions are replaced by MCP tools and which must be kept.

### Added

**GitHub Actions** — PR #45
- `auto-label-pr.yml` — automatically labels PRs based on branch prefix (`feature/` → feature, `fix/` → fix, `docs/` → docs, etc.) and adds size labels (XS/S/M/L/XL) based on total lines changed. Creates labels on first use with color coding

**MCP migration guide** — `mcp-migration.md` config rule
- Documents equivalence between `azdevops-queries.sh` functions and MCP tools
- 5 functions fully migrated to MCP: `get_current_sprint`, `get_sprint_items`, `get_board_status`, `update_workitem`, `batch_get_workitems`
- 3 functions kept in script (no MCP equivalent): `get_burndown_data` (Analytics OData), `get_team_capacities` (Work API), `get_velocity_history` (hybrid)
- Decision rule: CRUD → MCP, Analytics/OData/Capacities → keep script

### Changed
- `azdevops-queries.sh` header updated with migration notes and reference to `mcp-migration.md`
- `pm-workflow.md` updated with MCP migration reference

---

## [0.9.0] — 2026-02-27

Messaging & Voice Inbox: WhatsApp (personal, no requiere Business) y Nextcloud Talk como canales de comunicación bidireccional. El PM puede enviar mensajes de voz por WhatsApp y pm-workspace los transcribe con Faster-Whisper (local, sin APIs externas), interpreta la intención y propone el comando correspondiente. Tres modos de operación: manual, background polling y listener persistente. Adds 6 new commands, 1 skill, 1 config rule. Total: 81 slash commands, 13 skills.

### Added

**Messaging & Inbox commands (6)** — PR #44
- `/notify:whatsapp {contacto} {msg}` — enviar notificaciones e informes por WhatsApp al PM o grupo del equipo. Funciona con cuenta personal (no requiere Business). Soporta adjuntos (PDF, imágenes)
- `/whatsapp:search {query}` — buscar mensajes en WhatsApp como contexto: decisiones, acuerdos, conversaciones del equipo. Datos en SQLite local (nunca se envían a terceros)
- `/notify:nctalk {sala} {msg}` — enviar notificaciones a sala de Nextcloud Talk. Funciona con cualquier instancia Nextcloud (self-hosted o cloud). Soporta ficheros adjuntos via Nextcloud Files
- `/nctalk:search {query}` — buscar mensajes en Nextcloud Talk: decisiones y contexto del equipo
- `/inbox:check` — revisar mensajes nuevos en todos los canales configurados. Transcribe audios con Faster-Whisper (local), interpreta peticiones del PM y propone el comando de pm-workspace correspondiente
- `/inbox:start --interval {min}` — iniciar monitor de inbox en background. Polling cada N minutos mientras la sesión esté abierta. Se detiene automáticamente al cerrar sesión

**Voice Inbox skill** — transcripción de audio y flujo audio→texto→acción
- Faster-Whisper local (modelos: tiny, base, small, medium, large-v3)
- Detección automática de idioma
- Mapeo de intención: voz del PM → comando de pm-workspace con nivel de confianza
- Confirmación obligatoria antes de ejecutar (configurable)

**Messaging config rule** — `messaging-config.md`
- Configuración centralizada: WhatsApp (personal vía whatsmeow) + Nextcloud Talk (API REST v4)
- 3 modos de operación documentados con ejemplos: manual, background polling, listener persistente
- Documentación completa de primer uso, instalación y configuración de cada canal
- Referencia MCP tools (WhatsApp) y API endpoints (Nextcloud Talk)

### Changed
- Command count: 75 → 81 (+6 messaging & inbox)
- Skills count: 12 → 13 (+voice-inbox)
- Help command updated with Mensajería e Inbox (6) category
- `pm-workflow.md` updated with 6 new commands + 2 new references (messaging-config, voice-inbox)
- READMEs (ES/EN) updated with messaging & inbox commands

---

## [0.8.0] — 2026-02-27

DevOps Extended: Azure DevOps Wiki management, Test Plans visibility, and security alerts. Leverages remaining MCP tool domains. Adds 5 new commands. Total: 75 slash commands.

### Added

**DevOps Extended commands (5)** — PR #43
- `/wiki:publish {file} --project {p}` — publish markdown documentation to Azure DevOps Wiki. Supports create and update operations via MCP wiki tools
- `/wiki:sync --project {p}` — bidirectional sync between local docs and Azure DevOps Wiki. Three modes: status (compare), push (local→wiki), pull (wiki→local). Conflict detection
- `/testplan:status --project {p}` — Test Plans dashboard: active plans, suites, test cases, execution rates (passed/failed/blocked/not run), PBI test coverage, alerts for untested PBIs
- `/testplan:results --project {p} --run {id}` — detailed test run results: failure analysis, stack traces, flaky test detection, trend over last N runs, recommendations for Bug PBI creation
- `/security:alerts --project {p}` — security alerts from Azure DevOps Advanced Security: CVEs, exposed secrets, code vulnerabilities. Severity filtering, trend analysis, optional PBI creation for critical/high alerts

### Changed
- Command count: 70 → 75 (+5 DevOps Extended)
- Help command updated with DevOps Extended (5) category
- `pm-workflow.md` updated with 5 new command entries
- READMEs (ES/EN) updated with DevOps Extended commands

---

## [0.7.0] — 2026-02-27

Project Onboarding Pipeline: 5-phase automated workflow for onboarding new projects. From audit to kickoff in one pipeline. Adds 5 new commands. Total: 70 slash commands.

### Added

**Project Onboarding commands (5)** — PR #42
- `/project:audit --project {p}` — (Phase 1) Deep project audit: 8 dimensions (code quality, tests, architecture, debt, security, docs, CI/CD, team health). Generates prioritized action report with 3 tiers: critical, improvable, correct. Leverages `/debt:track`, `/kpi:dora`, `/pipeline:status`, `/sentry:health` internally
- `/project:release-plan --project {p}` — (Phase 2) Prioritized release plan from audit + backlog. Groups PBIs into releases respecting dependencies, risk, and business value. Supports greenfield and legacy (strangler fig) strategies
- `/project:assign --project {p}` — (Phase 3) Distribute work across team by skills, seniority, and capacity. Scoring algorithm: skill_match (40%) + capacity (30%) + seniority_fit (20%) + context_bonus (10%). Alerts for overload and bus factor
- `/project:roadmap --project {p}` — (Phase 4) Visual roadmap: Mermaid Gantt with milestones, dependencies, releases. Exports to Draw.io/Miro. Two audiences: tech (detailed) and executive (summary)
- `/project:kickoff --project {p}` — (Phase 5) Compile phases 1-4 into kickoff report. Notify PM via Slack/email. Optionally create Sprint 1 in Azure DevOps with Release 1 scope

### Changed
- Command count: 65 → 70 (+5 onboarding)
- Help command updated with Project Onboarding (5) category
- `pm-workflow.md` updated with 5 new onboarding command entries
- READMEs (ES/EN) updated with project onboarding commands

---

## [0.6.0] — 2026-02-27

Legacy assessment, backlog capture from unstructured sources, and automated release notes generation. Adds 3 new commands. Total: 65 slash commands.

### Added

**Legacy & Capture commands (3)** — PR #41
- `/legacy:assess --project {p}` — legacy application assessment: complexity score (6 dimensions), maintenance cost, risk rating, modernization roadmap using strangler fig pattern. Output: `output/assessments/YYYYMMDD-legacy-{project}.md`
- `/backlog:capture --project {p} --source {tipo}` — create PBIs from unstructured input: emails, meeting notes, Slack messages, support tickets. Deduplicates against existing backlog, classifies by type and priority
- `/sprint:release-notes --project {p}` — auto-generate release notes combining Azure DevOps work items + conventional commits + merged PRs. Three audience levels: tech, stakeholder, public

### Changed
- Command count: 62 → 65 (+3 legacy & capture)
- Help command updated with Legacy & Capture (3) category
- `pm-workflow.md` updated with 3 new command entries
- READMEs (ES/EN) updated with legacy & capture commands

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

[Unreleased]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.12.0...HEAD
[0.12.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.11.1...v0.12.0
[0.11.1]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/gonzalezpazmonica/pm-workspace/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/gonzalezpazmonica/pm-workspace/releases/tag/v0.1.0
