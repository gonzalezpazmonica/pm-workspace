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

**Programmatic hooks** — 12 hooks that enforce critical rules automatically: force push blocking, secrets detection, destructive infrastructure operation prevention, auto-lint after edits, quality gates before finishing, scope guard that detects files modified outside the SDD spec's declared scope, and persistent memory injection after compaction.

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

**Vertical detection** — I automatically detect if your project belongs to a non-software sector (healthcare, legal, industrial, agriculture, education, finance...) using a calibrated 5-phase scoring algorithm. If the score is sufficient, I propose creating specialized extensions with rules, workflows, and domain entities for your sector.

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
| [Commands and agents](docs/readme_en/12-commands-agents.md) | 135 commands + 24 specialized agents |
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

## Quick Command Reference

> 140 commands · 24 agents · 20 skills — full reference at [docs/readme_en/12-commands-agents.md](docs/readme_en/12-commands-agents.md)

### User Profile, Updates and Community
```
/profile-setup    /profile-edit    /profile-switch    /profile-show
/update {check|install|auto-on|auto-off|status}
/contribute {pr|idea|bug|status}    /feedback {bug|idea|improve|list|search}
/vertical-propose {name}
/review-community {pending|review|merge|release|summary}
```

### Technical Debt Intelligence
```
/debt-analyze    /debt-prioritize    /debt-budget
```

### AI Governance
```
/ai-model-card    /ai-risk-assessment    /ai-audit-log
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
```

### Memory and Context
```
/memory-sync    /memory-save    /memory-search    /memory-context
/context-load    /session-save    /help [filter]
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

*🦉 Savia — PM-Workspace, your automated PM with Claude Code + Azure DevOps for multi-language/Scrum teams*
