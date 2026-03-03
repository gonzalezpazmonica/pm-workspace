<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**English** · [Versión en español](README.md)

# PM-Workspace — Claude Code + Azure DevOps

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Contributors](https://img.shields.io/github/contributors/gonzalezpazmonica/pm-workspace)](CONTRIBUTORS.md)

> 🦉 **I'm Savia**, the little owl of pm-workspace. I keep your projects flowing: I manage sprints, backlog, reports, code agents, and cloud infrastructure — all from Claude Code, in **any language**, with Scrum and Azure DevOps.

> **🚀 First time here?** Check the [Adoption Guide for Consulting Firms](docs/ADOPTION_GUIDE.en.md) — step by step from Claude signup to project and team onboarding.

---

## Who am I?

I'm Savia — your automated PM / Scrum Master for projects on Azure DevOps. When you install me, the first thing I do is introduce myself and get to know you: your name, your role, how you work, what tools you use. I adapt to you, not the other way around.

I work with 16 languages (C#/.NET, TypeScript, Angular, React, Java/Spring, Python, Go, Rust, PHP/Laravel, Swift, Kotlin, Ruby, VB.NET, COBOL, Terraform, Flutter) and have conventions, rules, and specialized agents for each one.

**Sprint management** — I track burndown, team capacity, board status, KPIs, and generate automatic reports in Excel and PowerPoint.

**PBI decomposition** — I analyze the backlog, break PBIs into tasks with estimates, detect workload issues, and propose assignments using scoring (expertise × availability × balance × growth).

**Spec-Driven Development (SDD)** — Tasks become executable specs. A "developer" can be a human or a Claude agent. I implement handlers, repositories, and unit tests in the project's language.

**Infrastructure as Code** — I manage multi-cloud (Azure, AWS, GCP) with automatic resource detection, creation at the lowest tier, and scaling only with your approval.

**Multi-environment** — Support for DEV/PRE/PRO (configurable) with secrets protection — connection strings never go into the repository.

**Intelligent memory system** — I have language rules with auto-loading by file type, persistent auto memory per project, support for external projects via symlinks and `--add-dir`. My memory store (JSONL) features full-text search, hash-based deduplication, topic_key for evolving decisions, `<private>` tag filtering, and automatic context injection after compaction. My skills and agents use progressive disclosure with `context_cost` metadata to optimize context consumption.

**Programmatic hooks** — 14 hooks that enforce critical rules automatically: force push blocking, secrets detection, destructive infrastructure operation prevention, auto-lint after edits, quality gates before finishing, scope guard that detects files modified outside the SDD spec's declared scope, persistent memory injection after compaction, semantic commit validation and pre-merge quality gates.

**Agents with advanced capabilities** — Each subagent has persistent memory, preloaded skills, appropriate permission mode, and developer agents use `isolation: worktree` for parallel implementation without conflicts. Experimental support for Agent Teams (lead + teammates).

**Multi-agent coordination** — Agent-notes system for persistent inter-agent memory, TDD gate that blocks implementation without prior tests, pre-implementation security review (OWASP on the spec, not just code), Architecture Decision Records (ADR) for traceable decisions, and scope serialization rules for safe parallel sessions.

**Automated code review** — Pre-commit hook that analyzes staged files against domain rules (REJECT/REQUIRE/PREFER), with SHA256 cache to skip re-reviewing unchanged files. Guardian angel integrated into the commit flow.

**Security and compliance** — SAST analysis against OWASP Top 10, dependency vulnerability auditing, SBOM generation (CycloneDX), git history credential scanning, and enhanced leak detection (AWS, GitHub, OpenAI, Azure, JWT patterns).

**Azure DevOps validation** — When you connect a project, I automatically audit the configuration against my "ideal Agile": process template, work item types, states, fields, backlog hierarchy, and iterations. If incompatibilities are found, I generate a remediation plan for your approval.

**Validation and CI/CD** — Plan gate that warns when implementing without an approved spec, file size validation (≤150 lines), frontmatter and settings.json schema validation, and CI pipeline with automated checks on every PR.

**Predictive analytics** — Sprint completion forecasting with Monte Carlo simulation, Value Stream Mapping with E2E Lead Time and Flow Efficiency, velocity trending with anomaly detection, and WIP aging alerts. Data-driven metrics, not gut feelings.

**Agent observability** — Execution traces with token consumption, duration and outcome, cost estimation per model (Opus/Sonnet/Haiku), and efficiency metrics (success rate, re-work, first-pass). Automatic hook logs every subagent invocation.

**Developer Experience** — Adapted DX Core 4 surveys, automated dashboard with feedback loops and cognitive load proxy, and friction point analysis with actionable recommendations. I measure team experience, not just speed.

**AI governance and compliance** — Model cards documenting agents and models, risk assessment per EU AI Act categories, audit logs with full traceability, and governance rules with quarterly compliance checklist.

**Technical debt intelligence** — Automated hotspot analysis, temporal coupling and code smell detection, business impact prioritization with scoring model, and per-sprint debt budget with velocity impact projection.

**Architecture Intelligence** — I detect architecture patterns (Clean, Hexagonal, DDD, CQRS, MVC/MVVM, Microservices, Event-Driven) in repositories of any language, suggest improvements prioritized by impact, recommend architectures for new projects, verify integrity with fitness functions, and compare patterns for decision-making.

**Emergency mode (local LLM)** — Contingency plan for operating without cloud connection. Automatic Ollama setup scripts with hardware detection, recommended model download (Qwen 2.5), and transparent Claude Code configuration. Offline PM operations without LLM. Emergency documentation in English and Spanish.

**Regulatory Compliance Intelligence** — Automated compliance scanning across 12 regulated sectors. 5-phase calibrated sector auto-detection algorithm. I detect HIPAA/PCI violations, data retention failures, audit trail gaps, weak encryption, misconfigured access control. Auto-fix with post-fix re-verification.

**Performance Audit** — Static performance analysis without code execution. I detect heavy functions by cyclomatic + cognitive complexity, language-specific async anti-patterns, hotspots with O() estimation and N+1 query detection. Test-first workflow: I create characterization tests before optimizing.

**User profiles and agent mode** — When you arrive for the first time, I introduce myself and get to know you through a natural conversation. I store your fragmented profile (identity, workflow, tools, projects, preferences, tone) and load only what's needed for each operation. I also communicate with external agents (OpenClaw and similar) in machine-to-machine mode: structured YAML/JSON output, no narrative, just data and status codes.

**Community and collaboration** — I encourage you to contribute improvements, report bugs, or propose ideas. With `/contribute` you can create PRs directly to the repository, and with `/feedback` you can open issues. Before sending anything, I validate that no private data is included (PATs, corporate emails, project names, IPs) — your privacy comes first.

**Encrypted cloud backup** — With `/backup` I encrypt your profiles, configurations, and PATs with AES-256-CBC (PBKDF2, 100k iterations) before uploading to NextCloud or Google Drive. Automatic rotation of 7 backups. If you lose your machine, a single command restores everything after a fresh clone.

**Adaptive daily routine** — With `/daily-routine` I suggest the day's routine based on your role (PM, Tech Lead, QA, Product Owner, Developer, CEO/CTO). Each role sees the most relevant commands in the right order. You can also use `/health-dashboard` for a project health dashboard adapted to your perspective, with composite scoring and prioritized alerts.

**Context optimization** — With `/context-optimize` I analyze how you use pm-workspace and suggest optimizations to the context-map. With `/context-age` I compress and archive old decisions using semantic aging (episodic → compressed → archived). With `/context-benchmark` I empirically verify that critical information is well-positioned in the context. With `/hub-audit` I audit the dependency topology between rules, commands, and agents to detect critical hubs and orphan rules.

**Executive reports** — With `/ceo-report` I generate multi-project reports for leadership with portfolio traffic lights, key metrics, and recommendations. With `/ceo-alerts` I filter only alerts requiring C-level decisions. With `/portfolio-overview` I show a bird's-eye view of all projects with dependencies.

**QA Toolkit** — With `/qa-dashboard` I provide a quality panel with coverage, flaky tests, bugs, and escape rate. With `/qa-regression-plan` I analyze change impact and recommend which tests to run. With `/qa-bug-triage` I help classify bugs by severity and detect duplicates. With `/testplan-generate` I generate test plans from SDD specs or PBIs.

**Developer productivity** — With `/my-sprint` I show your personal sprint view with assigned items and cycle time. With `/my-focus` I identify your top priority item and load all its context. With `/my-learning` I detect improvement opportunities by analyzing your code. With `/code-patterns` I document project patterns with real code examples.

**Tech Lead intelligence** — With `\`/tech-radar\`` I map the tech stack with adopt/trial/hold/retire categorization. With `\`/team-skills-matrix\`` I build the team skills matrix with bus factor and pair programming suggestions. With `\`/arch-health\`` I measure architectural health with fitness functions, drift detection, and coupling metrics. With `\`/incident-postmortem\`` I structure blameless postmortems with timeline and root cause analysis.

**Product Owner Analytics** — With `/value-stream-map` I map the end-to-end value flow detecting bottlenecks. With `/feature-impact` I analyze feature impact on ROI, engagement, and technical load. With `/stakeholder-report` I generate executive reports for stakeholders with delivery metrics and objective alignment. With `/release-readiness` I verify release readiness: technical capacity, risks mitigated, communications prepared.

**Vertical detection** — I automatically detect if your project belongs to a non-software sector (healthcare, legal, industrial, agriculture, education, finance...) using a calibrated 5-phase scoring algorithm. If the score is sufficient, I propose creating specialized extensions with rules, workflows, and domain entities for your sector.

**Company Savia — Shared repository** — With `/company-repo` you create a shared Git repository for your company: org chart, rules, holidays, conventions. Each employee gets a personal folder with public profile, documents, and message inbox. With `/savia-send` you send direct messages using @handle, `/savia-inbox` checks your inbox, `/savia-reply` replies with threading, `/savia-announce` publishes company announcements, `/savia-directory` lists members, and `/savia-broadcast` sends to everyone. E2E encryption with RSA-4096 + AES-256-CBC (openssl only), pre-push privacy validation, and zero external dependencies.

**Savia Flow — Git-based project management** — With `/savia-pbi` you create and manage PBIs as markdown files in the company repo, with a state machine (new/ready/in-progress/review/done). With `/savia-sprint` you manage the sprint lifecycle (start/close). With `/savia-board` you display a 5-column ASCII Kanban board. With `/savia-timesheet` you log hours per PBI with monthly reports. With `/savia-team` you manage teams with capacity, ceremonies, and velocity. Everything stored in Git — no Azure DevOps dependency.

**Travel Mode** — With `/savia-travel-pack` you create a portable pm-workspace package for USB or cloud (shallow clone + manifest + encrypted backup). With `/savia-travel-init` you bootstrap pm-workspace on a new machine: detects OS, verifies dependencies, installs Claude Code, and restores profile.

---

## Documentation

I've organized all documentation into sections so you can quickly find what you need:

### Getting Started

| Section | Description |
|---|---|
| [Introduction and quick example](docs/readme_en/01-introduction.md) | First 5 minutes with the workspace |
| [Workspace structure](docs/readme_en/02-structure.md) | Directories, files, and organization |
| [Initial setup](docs/readme_en/03-setup.md) | PAT, constants, dependencies, verification |
| [Adoption guide](docs/ADOPTION_GUIDE.en.md) | Step by step for consulting firms |

### Daily Use

| Section | Description |
|---|---|
| [Sprints and reports](docs/readme_en/04-usage-sprint-reports.md) | Sprint management, reporting, workload, KPIs |
| [Spec-Driven Development](docs/readme_en/05-sdd.md) | Full SDD: specs, agents, team patterns |
| [Advanced configuration](docs/readme_en/06-advanced-config.md) | Assignment weights, SDD config per project |

### Infrastructure and Deployment

| Section | Description |
|---|---|
| [Project infrastructure](docs/readme_en/07-infrastructure.md) | Define compute, databases, API gateways, storage |
| [Pipelines (PR and CI/CD)](docs/readme_en/08-pipelines.md) | Define validation and deployment pipelines |

### Reference

| Section | Description |
|---|---|
| [Test project](docs/readme_en/09-test-project.md) | `sala-reservas`: tests, mock data, validation |
| [KPIs, rules, and roadmap](docs/readme_en/10-kpis-rules.md) | Metrics, critical rules, adoption plan |
| [Onboarding new team members](docs/readme_en/11-onboarding.md) | 5-phase onboarding, competency evaluation, GDPR |
| [Commands and agents](docs/readme_en/12-commands-agents.md) | 271 commands + 24 specialized agents |
| [Coverage and contributing](docs/readme_en/13-coverage-contributing.md) | What's covered, what's not, how to contribute |

### Other Documents

| Document | Description |
|---|---|
| [Best practices Claude Code](docs/best-practices-claude-code.md) | Usage best practices |
| [Language incorporation guide](docs/guia-incorporacion-lenguajes.md) | How to add support for new languages |
| [Scrum rules](docs/reglas-scrum.md) | Workspace Scrum management rules |
| [Estimation policy](docs/politica-estimacion.md) | Estimation criteria |
| [Team KPIs](docs/kpis-equipo.md) | KPI definitions |
| [Report templates](docs/plantillas-informes.md) | Reporting templates |
| [Workflow](docs/flujo-trabajo.md) | Complete workflow |
| [Memory system](docs/memory-system.md) | Auto-loading, auto memory, symlinks, `--add-dir` |
| [Agent Teams SDD](docs/agent-teams-sdd.md) | Parallel implementation with lead + teammates |
| [Agent Notes Protocol](docs/agent-notes-protocol.md) | Inter-agent memory, handoffs, traceability |
| [Emergency guide](docs/EMERGENCY.en.md) | Offline mode with local LLM, contingency scripts |

---

## v0.71.0 — Observability Core

- `/obs-connect` — Connect to Grafana, Datadog, App Insights, OpenTelemetry
- `/obs-query` — Natural language queries to observability data
- `/obs-dashboard` — Dashboards digested by role
- `/obs-status` — Health check of connected sources

---

## v0.72.0 — Trace Intelligence

- `/trace-search` — Search and filter traces in Grafana, Datadog, App Insights with natural language
- `/trace-analyze` — Deep trace analysis: waterfall, bottleneck detection, error chain
- `/error-investigate` — AI-assisted error investigation with root cause hypothesis
- `/incident-correlate` — Cross-source incident correlation with post-mortem draft

**Era 17 — AI Tooling & Auto-Compact (3/3). ERA 17 COMPLETE!**

## v0.84.0–v0.89.0 — Era 18: Compliance, Distribution & Intelligent Hooks

- `/aepd-compliance` — AEPD compliance audit for agentic AI (4 phases: technology → compliance → vulnerabilities → measures)
- `/excel-report` — Interactive Excel templates (capacity, CEO, time-tracking) in multi-tab CSV
- `/savia-gallery` — Interactive catalog of 271 commands by role and vertical with source tracking
- skills.sh publishing infrastructure — Adapter script + format for marketplace publishing
- Intelligent hooks — Prompt hooks (semantic) and Agent hooks (pre-merge quality gate)
- AI Competency Framework — 6 AI-era competencies for `/adoption-assess --ai-skills`

**Era 18 — Compliance, Distribution & Intelligent Hooks (6/6). ERA 18 COMPLETE!**

## Quick Command Reference

> 327 commands · 24 agents · 22 skills — full reference at [docs/readme_en/12-commands-agents.md](docs/readme_en/12-commands-agents.md)

### User Profile, Updates and Community
```
/profile-setup    /profile-edit    /profile-switch    /profile-show
/update {check|install|auto-on|auto-off|status}
/contribute {pr|idea|bug|status}    /feedback {bug|idea|improve|list|search}
/vertical-propose {name}
/banking-detect    /banking-bian    /banking-eda-validate    /banking-data-governance    /banking-mlops-audit
/flow-setup    /flow-board    /flow-intake    /flow-metrics    /flow-spec
/review-community {pending|review|merge|release|summary}
/backup {now|restore|auto-on|auto-off|status}
/daily-routine    /health-dashboard {project|all|trend}
/context-optimize {stats|reset|apply}
/context-age {status|apply}    /context-benchmark {quick|history}
/hub-audit {quick|update}
/ceo-report {project|--format md|pdf|pptx}
/ceo-alerts {project|--history}    /portfolio-overview {--compact|--deps}
/qa-dashboard {project|--trend}    /qa-regression-plan {branch|--pr}
/qa-bug-triage {bug-id|--backlog}    /testplan-generate {spec|--pbi|--sprint}

### Developer Productivity
```
/my-sprint {--all|--history}    /my-focus {--next|--list}
/my-learning {--quick|--topic}    /code-patterns {pattern|--new}
```

### Tech Lead Intelligence
```
/tech-radar {project|--outdated}    /team-skills-matrix {--bus-factor|--pairs}
/arch-health {--drift|--coupling}    /incident-postmortem {desc|--from-alert|--list}
```

### Product Owner Analytics
```
/value-stream-map {--bottlenecks}    /feature-impact {--roi}
/stakeholder-report    /release-readiness
```

### Intelligent Backlog Management
```
/backlog-groom {--top N|--duplicates|--incomplete}    /backlog-prioritize {--method|--strategy-aligned}
/outcome-track {--release vX.Y.Z|--register}    /stakeholder-align {--items|--scenario}
```

### Ceremony Intelligence
```
/async-standup {--compile|--start|--deadline HH:MM|--list}    /retro-patterns {--sprints N|--method|--action-items}
/ceremony-health {--sprints N|--ceremony type|--metric}    /meeting-agenda {--type|--sprint|--duration}
```

### Cross-Project Intelligence
```
/portfolio-deps {--critical}    /backlog-patterns
/org-metrics {--trend 6}    /cross-project-search {query}
```

### AI-Powered Planning
```
/sprint-autoplan {--conservative}    /risk-predict {--sprint N}
/meeting-summarize {--type daily}    /capacity-forecast {--sprints 6}
```

### Integration Hub
```
/mcp-server {start|stop}    /nl-query {question}
/webhook-config {add|list}    /integration-status {--check}
```

### Multi-Platform
```
/jira-connect {setup|sync|map}    /github-projects {connect|board}
/linear-sync {setup|pull|push}    /platform-migrate {plan|execute}
```

### Company Intelligence
```
/company-setup {--quick}    /company-edit {section}
/company-show {--gaps}    /company-vertical {detect|configure}
```

### OKR & Strategy
```
/okr-define {--template|--import}    /okr-track {--objective|--trend}
/okr-align {--gaps|--project}    /strategy-map {--initiative|--dependencies}
```

### Technical Debt Intelligence
```
/debt-analyze    /debt-prioritize    /debt-budget
```

### AI Governance
```
/ai-safety-config    /ai-confidence    /ai-boundary    /ai-incident
/ai-model-card    /ai-risk-assessment    /ai-audit-log
```

### AI Adoption Companion
```
/adoption-assess    /adoption-plan    /adoption-sandbox    /adoption-track
```

### Sprint and Reporting
```
/sprint-status    /sprint-plan    /sprint-review    /sprint-retro
/sprint-release-notes    /report-hours    /report-executive    /report-capacity
/team-workload    /board-flow    /kpi-dashboard    /kpi-dora
/sprint-forecast    /flow-metrics    /velocity-trend
```

### PBI and SDD
```
/pbi-decompose {id}    /pbi-decompose-batch {ids}    /pbi-assign {id}
/pbi-plan-sprint    /pbi-jtbd {id}    /pbi-prd {id}
/spec-generate {id}    /spec-explore {id}    /spec-design {spec}
/spec-implement {spec}    /spec-review {file}    /spec-verify {spec}
/spec-status    /agent-run {file}
```

### Repositories, PRs and Pipelines
```
/repos-list    /repos-branches {repo}    /repos-search {query}
/repos-pr-create    /repos-pr-list    /repos-pr-review {pr}
/pr-review [PR]    /pr-pending
/pipeline-status    /pipeline-run {pipe}    /pipeline-logs {id}
/pipeline-artifacts {id}    /pipeline-create {repo}
```

### Infrastructure and Environments
```
/infra-detect {proj} {env}    /infra-plan {proj} {env}    /infra-estimate {proj}
/infra-scale {resource}    /infra-status {proj}
/env-setup {proj}    /env-promote {proj} {source} {dest}
```

### Projects and Planning
```
/project-kickoff {name}    /project-assign {name}    /project-audit {name}
/project-roadmap {name}    /project-release-plan {name}
/epic-plan {proj}    /backlog-capture    /retro-actions
/rpi-start {feature}    /rpi-status [feature] [--all]
```

### Memory and Context
```
/memory-sync    /memory-save    /memory-search    /memory-context
/context-load    /session-save    /help [filter]
/agent-memory {list|show|clear}    /savia-recall {topic}    /savia-forget {topic|--all}
```

### Security and Auditing
```
/security-review {spec}    /security-audit    /security-alerts
/credential-scan    /dependencies-audit    /sbom-generate
```

### Quality and Validation
```
/changelog-update    /evaluate-repo [URL]    /validate-filesize
/validate-schema    /review-cache-stats    /review-cache-clear
/testplan-status    /testplan-results {id}    /devops-validate {proj}
/mcp-recommend [--stack dotnet|python|node] [--role pm|dev|qa]
```

### Developer Experience
```
/dx-survey    /dx-dashboard    /dx-recommendations
```

### Agent Observability
```
/agent-trace    /agent-cost    /agent-efficiency
```

### Team and Onboarding
```
/team-onboarding {name}    /team-evaluate {name}    /team-privacy-notice {name}
/onboard --role {dev|pm|qa} [--project name]
```

### Architecture Intelligence
```
/arch-detect {repo|path}    /arch-suggest {repo|path}    /arch-recommend {reqs}
/arch-fitness {repo|path}    /arch-compare {pattern1} {pattern2}
```

### Architecture and Diagrams
```
/adr-create {proj} {title}    /agent-notes-archive {proj}
/diagram-generate {proj}    /diagram-import {file}
/diagram-config    /diagram-status
/debt-track    /dependency-map    /legacy-assess    /risk-log
```

### Regulatory Compliance Intelligence
```
/compliance-scan {repo|path}    /compliance-fix {repo|path}    /compliance-report {repo|path}
```

### Performance Audit
```
/perf-audit {path}              /perf-fix {PA-NNN}              /perf-report {path}
```

### Savia Flow (Git-based PM)
```
/savia-pbi {create|view|list}    /savia-sprint {start|close|plan}
/savia-board {project}    /savia-timesheet {log|view}    /savia-team {init|members|velocity}
```

### Travel Mode
```
/travel-pack    /travel-unpack    /travel-sync    /travel-verify    /travel-clean
/savia-travel-pack    /savia-travel-init
```

### Git Persistence Engine
```
/index-rebuild {--all|--profiles|--messages|--projects|--specs|--timesheets}
/index-status {--detailed}    /index-compact
```

### Savia Flow Git-Native Tasks
```
/flow-task-create {type} {title}    /flow-task-move {task-id} {status}
/flow-task-assign {task-id} {handle}    /flow-sprint-create {goal}
/flow-sprint-close {sprint-id}    /flow-sprint-board
/flow-timesheet {task-id} {hours}    /flow-timesheet-report {--monthly|--weekly}
/flow-burndown    /flow-velocity    /flow-spec-create {title}
/flow-backlog-groom {--top N}
```

### Savia School (Education Vertical)
```
/school-setup {school} {course}    /school-enroll {alias}
/school-project {alias} {name}    /school-submit {alias} {project}
/school-evaluate {alias} {project}    /school-progress {alias|--class}
/school-portfolio {alias}    /school-diary {alias}
/school-export {alias}    /school-forget {alias}
/school-analytics    /school-rubric {create|edit}
```

### Emergency
```
/emergency-plan [--model MODEL]    /emergency-mode {setup|status|activate|deactivate|test}
```

### External Integrations
```
/jira-sync    /linear-sync    /notion-sync    /confluence-publish
/wiki-publish    /wiki-sync    /slack-search    /notify-slack
/notify-whatsapp    /whatsapp-search    /notify-nctalk    /nctalk-search
/figma-extract    /gdrive-upload    /github-activity    /github-issues
/sentry-bugs    /sentry-health    /inbox-check    /inbox-start
/worktree-setup {spec}
```

---

## Critical Rules

These are the rules that are never skipped — not even by me:

1. **NEVER hardcode the PAT** — always `$(cat $PAT_FILE)`
2. **Confirm before writing** to Azure DevOps — I ask before modifying data
3. **Read the project's CLAUDE.md** before acting on it
4. **SDD**: NEVER launch agent without approved Spec; Code Review ALWAYS human
5. **Secrets**: NEVER connection strings, API keys, or passwords in the repository
6. **Infrastructure**: NEVER `terraform apply` in PRE/PRO without human approval; always minimum tier
7. **Git**: NEVER commit directly to `main` — always branch + PR
8. **Commands**: validate with `scripts/validate-commands.sh` before committing
9. **Parallel**: verify scope overlap before launching Agent Teams; serialize if conflict

---

## v0.90.0 — Era 19: Open Source Synergy

- `/mcp-browse` — Browse 66+ MCPs from the claude-code-templates ecosystem
- `/component-search` — Search 5,788+ components (agents, commands, hooks, MCPs, skills)
- `docs/recommended-mcps.md` — Curated MCP catalog for PM/Scrum teams
- `hooks/README.md` — Categorized documentation for all 14 hooks (security, quality gates, agents, workflow)
- `agent-observability-patterns.md` — Observability patterns inspired by analytics dashboard
- `component-marketplace.md` — Component marketplace integration rule

**Era 19 — Open Source Synergy (6/6). ERA 19 COMPLETE!**

## v0.91.0–v0.98.0 — Era 20: Persistent Intelligence & Adaptive Workflows

- v0.91.0 — 5 bug fixes + 165 new tests (64→229). 7 test scripts + orchestrator `test-stress-runner.sh`
- `/agent-memory` — Persistent memory for 9 agents with 3 scopes (project/local/user)
- `/savia-recall` — Query Savia's accumulated contextual memory
- `/savia-forget` — GDPR-compliant memory pruning (Art. 17 RGPD)
- 57 commands with smart frontmatter (`model`, `context_cost`, `allowed-tools`)
- `/rpi-start` — Research → Plan → Implement workflow with GO/NO-GO gates
- `/rpi-status` — Track active RPI workflow progress
- `/onboard --role {dev|pm|qa}` — Guided onboarding with role-specific checklists
- `/mcp-recommend` — MCP recommendations by stack and team role
- 3 adaptive output modes: Coaching · Executive · Technical
- Hook classification: 2 async + 10 blocking, 9/16 event coverage
- `pr-guardian.yml` — 8 automated PR validation gates (context guard, ShellCheck, Gitleaks, hook safety, PR Digest in Spanish)
- `/pr-digest` — Contextual PR analysis with risk classification and executive summary

**Era 20 — Persistent Intelligence (14/14). ERA 20 COMPLETE!**

---

## Special Acknowledgment

This project thrives on the open source ecosystem of Claude Code tools. We want to give special thanks to:

### [claude-code-templates](https://github.com/davila7/claude-code-templates)

Created by [Daniel Avila](https://github.com/davila7), claude-code-templates is the largest component marketplace for Claude Code: **5,788+ components** (agents, commands, hooks, MCPs, settings, skills), a **CLI installer** (`npx claude-code-templates@latest`), a **web catalog** at [aitmpl.com](https://aitmpl.com), and a **dashboard** at [app.aitmpl.com](https://app.aitmpl.com). With 21K+ stars, it's an essential reference for any team working with Claude Code.

pm-workspace integrates components from this ecosystem and contributes back with enterprise hooks, PM/Scrum agents, and specialized skills. If you're looking for free tools for Claude Code, start there.

```bash
# Install components from the marketplace
npx claude-code-templates@latest

# Explore from pm-workspace
/mcp-browse
/component-search {term}
```

---

*🦉 Savia — PM-Workspace, your automated PM with Claude Code + Azure DevOps for multi-language/Scrum teams*
