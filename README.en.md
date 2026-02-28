<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**English** · [Versión en español](README.md)

# PM-Workspace — Claude Code + Azure DevOps

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Contributors](https://img.shields.io/github/contributors/gonzalezpazmonica/pm-workspace)](CONTRIBUTORS.md)

> A **multi-language** project management system built on Scrum, powered by Claude Code as an automated PM/Scrum Master — with the ability to delegate technical implementation to AI agents and manage cloud infrastructure.

> **🚀 First time here?** Check the [Adoption Guide for Consulting Firms](docs/ADOPTION_GUIDE.en.md) — step by step from Claude signup to project and team onboarding.

---

## What is this?

This workspace turns Claude Code into an **automated Project Manager / Scrum Master** for projects in **any language** on Azure DevOps. It supports 16 languages (C#/.NET, TypeScript, Angular, React, Java/Spring, Python, Go, Rust, PHP/Laravel, Swift, Kotlin, Ruby, VB.NET, COBOL, Terraform, Flutter) with conventions, rules, and specialized agents for each.

**Sprint management** — burndown tracking, team capacity, board status, KPIs, automatic reports in Excel/PowerPoint.

**PBI decomposition** — analyzes backlog, breaks PBIs into tasks with estimates, detects workload balance, and proposes assignments using scoring (expertise × availability × balance × growth).

**Spec-Driven Development (SDD)** — tasks become executable specs. A "developer" can be a human or a Claude agent. Automatic implementation of handlers, repositories, unit tests in the project's language.

**Infrastructure as Code** — multi-cloud management (Azure, AWS, GCP) with automatic resource detection, creation at the lowest tier, and scaling only with human approval.

**Multi-environment** — support for DEV/PRE/PRO (configurable) with secrets protection — connection strings never go into the repository.

**Intelligent memory system** — language rules with auto-loading by file type (`paths:` frontmatter), persistent auto memory per project, support for external projects via symlinks and `--add-dir`. Persistent memory store (JSONL) with full-text search, hash-based deduplication, topic_key for evolving decisions, `<private>` tag filtering, and automatic context injection after compaction. Skills and agents use progressive disclosure (`references/`) with `context_cost` metadata to optimize context consumption.

**Programmatic hooks** — 12 hooks that enforce critical rules automatically: force push blocking, secrets detection, destructive infrastructure operation prevention, auto-lint after edits, quality gates before finishing, scope guard that detects files modified outside the SDD spec's declared scope, and persistent memory injection after compaction. Configured in `.claude/settings.json`.

**Agents with advanced capabilities** — each subagent has persistent memory (`memory: project`), preloaded skills, appropriate permission mode, and developer agents use `isolation: worktree` for parallel implementation without conflicts. Experimental support for Agent Teams (lead + teammates).

**Multi-agent coordination** — agent-notes system for persistent inter-agent memory, TDD gate that blocks implementation without prior tests, pre-implementation security review (OWASP on the spec, not just code), Architecture Decision Records (ADR) for traceable decisions, and scope serialization rules for safe parallel sessions.

**Automated code review** — pre-commit hook that analyzes staged files against domain rules (REJECT/REQUIRE/PREFER), with SHA256 cache to skip re-reviewing unchanged files. Guardian angel integrated into the commit flow.

**Security and compliance** — SAST analysis against OWASP Top 10, dependency vulnerability auditing, SBOM generation (CycloneDX), git history credential scanning, and enhanced leak detection (AWS, GitHub, OpenAI, Azure, JWT patterns).

**Validation and CI/CD** — plan gate that warns when implementing without an approved spec, file size validation (≤150 lines), frontmatter and settings.json schema validation, and CI pipeline with automated checks on every PR.

**Predictive analytics** — sprint completion forecasting with Monte Carlo simulation, Value Stream Mapping with E2E Lead Time and Flow Efficiency, velocity trending with anomaly detection, and WIP aging alerts. Data-driven metrics, not gut feelings.

**Agent observability** — execution traces with token consumption, duration and outcome, cost estimation per model (Opus/Sonnet/Haiku), and efficiency metrics (success rate, re-work, first-pass). Automatic hook logs every subagent invocation.

**Developer Experience** — adapted DX Core 4 surveys, automated dashboard with feedback loops and cognitive load proxy, and friction point analysis with actionable recommendations. Measures team experience, not just speed.

---

## Documentation

Full documentation is organized into sections for easy reference:

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
| [Commands and agents](docs/readme_en/12-commands-agents.md) | 111 commands + 24 specialized agents |
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

---

## Quick Command Reference

> 111 commands · 24 agents · 15 skills — full reference at [docs/readme_en/12-commands-agents.md](docs/readme_en/12-commands-agents.md)

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
/testplan-status    /testplan-results {id}
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

### Architecture and Diagrams
```
/adr-create {proj} {title}    /agent-notes-archive {proj}
/diagram-generate {proj}    /diagram-import {file}
/diagram-config    /diagram-status
/debt-track    /dependency-map    /legacy-assess    /risk-log
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

1. **NEVER hardcode the PAT** — always `$(cat $PAT_FILE)`
2. **Confirm before writing** to Azure DevOps — ask before modifying data
3. **Read the project's CLAUDE.md** before acting on it
4. **SDD**: NEVER launch agent without approved Spec; Code Review ALWAYS human
5. **Secrets**: NEVER connection strings, API keys, or passwords in the repository
6. **Infrastructure**: NEVER `terraform apply` in PRE/PRO without human approval; always minimum tier
7. **Git**: NEVER commit directly to `main` — always branch + PR
8. **Commands**: validate with `scripts/validate-commands.sh` before committing
9. **Parallel**: verify scope overlap before launching Agent Teams; serialize if conflict

---

*PM-Workspace — Claude Code + Azure DevOps strategy for multi-language/Scrum teams with cloud infrastructure support*
