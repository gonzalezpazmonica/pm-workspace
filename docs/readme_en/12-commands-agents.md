# Quick Command Reference

## Sprint and Reporting (15 commands)
```
/sprint-status [--project]        Sprint status with alerts
/sprint-plan [--project]          Sprint Planning assistant
/sprint-review [--project]        Sprint Review summary
/sprint-retro [--project]         Retrospective with data
/sprint-release-notes [--project] Generate sprint release notes
/report-hours [--project]         Hours report (Excel)
/report-executive                 Multi-project report (PPT/Word)
/report-capacity [--project]      Team capacity status
/team-workload [--project]        Workload per person
/board-flow [--project]           Cycle time and bottlenecks
/kpi-dashboard [--project]        Full KPI dashboard
/kpi-dora [--project]             DORA metrics (deploy freq, lead time, MTTR, change fail)
/sprint-forecast [--project]      Sprint completion forecast with Monte Carlo
/flow-metrics [--project]         Value Stream dashboard (Lead Time, Flow Efficiency, WIP)
/velocity-trend [--project]       Velocity trend and anomaly detection
```

## AI Governance (3 commands)
```
/ai-model-card [--project]        AI agent model card
/ai-risk-assessment [--project]   EU AI Act risk assessment
/ai-audit-log [--project]         AI execution audit log
```

## PBI and Decomposition (6 commands)
```
/pbi-decompose {id}               Break down a PBI into tasks
/pbi-decompose-batch {id1,id2}    Break down multiple PBIs
/pbi-assign {pbi_id}              (Re)assign tasks for a PBI
/pbi-plan-sprint                  Full sprint planning
/pbi-jtbd {id}                    Generate JTBD (Jobs to be Done)
/pbi-prd {id}                     Generate PRD (Product Requirements)
```

## Spec-Driven Development (8 commands)
```
/spec-generate {task_id}          Generate Spec from Azure DevOps Task
/spec-explore {id}                Pre-spec codebase exploration
/spec-design {spec}               Technical design from spec
/spec-implement {spec_file}       Implement Spec (agent or human)
/spec-review {spec_file}          Review Spec quality or implementation
/spec-verify {spec}               Verify implementation vs spec (Given/When/Then)
/spec-status [--project]          Sprint Spec dashboard
/agent-run {spec_file} [--team]   Launch Claude agent on a Spec
```

## Repositories and PRs (8 commands)
```
/repos-list [--project]           List project repositories
/repos-branches {repo}            Active branches for a repository
/repos-search {query}             Search source code
/repos-pr-create {repo}           Create Pull Request
/repos-pr-list [--project]        List open PRs
/repos-pr-review {pr_id}          Review an Azure DevOps PR
/pr-review [PR]                   Multi-perspective review (BA, Dev, QA, Sec, DevOps)
/pr-pending [--project]           PRs pending review
```

## Pipelines CI/CD (5 commands)
```
/pipeline-status [--project]      Pipeline status
/pipeline-run {pipeline}          Run a pipeline
/pipeline-logs {run_id}           View execution logs
/pipeline-artifacts {run_id}      Download artifacts
/pipeline-create {repo}           Create pipeline from template
```

## Infrastructure and Environments (7 commands)
```
/infra-detect {project} {env}     Detect existing infrastructure
/infra-plan {project} {env}       Generate infrastructure plan
/infra-estimate {project}         Estimate costs per environment
/infra-scale {resource}           Propose scaling (requires human approval)
/infra-status {project}           Current infrastructure status
/env-setup {project}              Configure environments (DEV/PRE/PRO)
/env-promote {project} {s} {d}    Promote between environments
```

## Projects and Planning (7 commands)
```
/project-kickoff {name}           Start new project (structure + Azure DevOps)
/project-assign {name}            Assign team to project
/project-audit {name}             Project health audit
/project-roadmap {name}           Generate visual roadmap
/project-release-plan {name}      Release plan
/epic-plan {project}              Multi-sprint epic planning
/backlog-capture                  Quick backlog item capture
```

## Memory and Context (6 commands)
```
/memory-sync [--project]          Sync insights to auto memory
/memory-save {type} {content}     Save to persistent memory
/memory-search {query}            Search memory
/memory-context                   Inject memory context
/context-load                     Load session context on startup
/session-save                     Save decisions before /clear
```

## Security and Auditing (5 commands)
```
/security-review {spec}           OWASP pre-implementation review
/security-audit [--project]       SAST analysis against OWASP Top 10
/security-alerts [--project]      Active security alerts
/credential-scan [--project]      Scan git history for leaked credentials
/dependencies-audit [--project]   Dependency vulnerability audit
```

## Testing (2 commands)
```
/testplan-status [--project]      Test plan status
/testplan-results {plan_id}       Test execution results
```

## Quality and Validation (7 commands)
```
/changelog-update                 Update CHANGELOG from commits
/evaluate-repo [URL]              External repo audit
/validate-filesize                Validate ≤150 lines per file
/validate-schema                  Validate frontmatter and settings schema
/review-cache-stats               Code review cache statistics
/review-cache-clear               Clear code review cache
/sbom-generate [--project]        Generate SBOM (Software Bill of Materials)
```

## Developer Experience (3 commands)
```
/dx-survey [--project]            Adapted DX Core 4 survey
/dx-dashboard [--project]         Automated DX dashboard
/dx-recommendations [--project]   Friction points and recommendations
```

## Agent Observability (3 commands)
```
/agent-trace [--project]          Agent execution traces
/agent-cost [--project] [--sprint] Cost estimation per model and command
/agent-efficiency [--project]     Efficiency metrics and re-work rates
```

## Team and Onboarding (3 commands)
```
/team-onboarding {name}           Personalized onboarding guide
/team-evaluate {name}             Competency questionnaire
/team-privacy-notice {name}       GDPR privacy notice
```

## External Integrations (12 commands)
```
/jira-sync {project}              Sync Jira ↔ Azure DevOps
/linear-sync {project}            Sync Linear ↔ Azure DevOps
/notion-sync {project}            Sync documentation ↔ Notion
/confluence-publish {doc}         Publish to Confluence
/wiki-publish {doc}               Publish to Azure DevOps Wiki
/wiki-sync [--project]            Sync wiki
/slack-search {query}             Search Slack
/notify-slack {channel} {msg}     Notify on Slack
/notify-whatsapp {dest} {msg}     Notify via WhatsApp
/whatsapp-search {query}          Search WhatsApp
/notify-nctalk {room} {msg}       Notify on Nextcloud Talk
/nctalk-search {query}            Search Nextcloud Talk
```

## Diagrams (4 commands)
```
/diagram-generate {project}       Generate architecture diagram
/diagram-import {file}            Import diagram → generate Work Items
/diagram-config                   Configure diagram tools
/diagram-status [--project]       Project diagram status
```

## Architecture Intelligence (5 commands)
```
/arch-detect {repo|path}         Detect architecture pattern of a project
/arch-suggest {repo|path}        Suggest prioritized architecture improvements
/arch-recommend {requirements}   Recommend architecture for new project
/arch-fitness {repo|path}        Run architecture fitness functions
/arch-compare {pattern1} {pattern2} Compare two architecture patterns
```

## Technical Debt Intelligence (3 commands)
```
/debt-analyze [--project]         Automated debt analysis (hotspots, coupling, smells)
/debt-prioritize [--project]      Business impact prioritization and ROI
/debt-budget [--sprint]           Per-sprint technical debt budget
```

## AI Governance (3 commands)
```
/ai-model-card [--project]        AI agent model card
/ai-risk-assessment [--project]   EU AI Act risk assessment
/ai-audit-log [--project]         AI execution audit log
```

## Emergency (1 command)
```
/emergency-mode {subcommand}     Manage emergency mode with local LLM (setup/status/activate/deactivate/test)
```

## Other (10 commands)
```
/help [filter]                    Command catalog and first steps
/adr-create {project} {title}     Create Architecture Decision Record
/agent-notes-archive {proj}       Archive sprint agent-notes
/debt-track [--project]           Technical debt tracking
/dependency-map [--project]       Service dependency map
/legacy-assess {project}          Legacy system assessment
/risk-log [--project]             Project risk register
/retro-actions [--project]        Retrospective action tracking
/worktree-setup {spec}            Set up git worktree for parallel implementation
/inbox-check                      Check pending voice inbox
/inbox-start                      Start voice mailbox transcription
/figma-extract {url}              Extract design from Figma
/gdrive-upload {file}             Upload file to Google Drive
/github-activity [--project]      Recent GitHub activity
/github-issues [--project]        GitHub issues
/sentry-bugs [--project]          Sentry bugs → PBIs
/sentry-health [--project]        Technical health from Sentry
```

---

## Specialized Agent Team

The workspace includes 24 specialized agents organized in 3 groups, each optimized for its task with the most suitable LLM model:

### Management & Architecture Agents

| Agent | Model | When to use |
|---|---|---|
| `architect` | Opus 4.6 | Multi-language architecture design, layer assignment, technical decisions |
| `business-analyst` | Opus 4.6 | PBI analysis, business rules, acceptance criteria, JTBD, PRD, competency assessment |
| `sdd-spec-writer` | Opus 4.6 | Generation and validation of executable SDD Specs |
| `infrastructure-agent` | Opus 4.6 | IaC (Terraform, CloudFormation, Bicep), detect + plan multi-cloud infrastructure |
| `diagram-architect` | Sonnet 4.6 | Architecture diagram design, C4, data flows |

### Language-Specific Developer Agents (16 Language Packs)

| Agent | Model | When to use |
|---|---|---|
| `{lang}-developer` | Sonnet 4.6 | Implementation of specs for 16 languages (C#, TypeScript, Java, Python, Go, Rust, PHP, Swift, Kotlin, Ruby, VB.NET, COBOL, Terraform, Flutter, etc.) |
| `{lang}-test-engineer` | Sonnet 4.6 | Language-specific unit tests (xUnit, Vitest, pytest, etc.) |

### Quality & Operations Agents

| Agent | Model | When to use |
|---|---|---|
| `code-reviewer` | Opus 4.6 | Quality gate: security, SOLID, language-specific linting rules |
| `security-guardian` | Opus 4.6 | Security and confidentiality audit before commit |
| `test-runner` | Sonnet 4.6 | Test execution, coverage verification, test improvement orchestration |
| `commit-guardian` | Sonnet 4.6 | Pre-commit: 10 checks (branch, security, build, tests, format, code review, README, CLAUDE.md, atomicity, message) |
| `tech-writer` | Haiku 4.5 | README, CHANGELOG, documentation, code comments |
| `azure-devops-operator` | Haiku 4.5 | WIQL queries, create/update work items, sprint management |

### SDD flow with parallel agents

```
User: /pbi-plan-sprint --project Alpha

  ┌─ business-analyst (Opus) ─────────────────┐
  │  Analyze candidate PBIs                   │   IN PARALLEL
  │  Verify business rules                    │
  └───────────────────────────────────────────┘
  ┌─ azure-devops-operator (Haiku) ───────────┐
  │  Get active sprint + capacities           │   IN PARALLEL
  └───────────────────────────────────────────┘
           ↓ (combined results)
  ┌─ architect (Opus) ────────────────────────┐
  │  Assign layers to each task               │
  │  Detect technical dependencies            │
  └───────────────────────────────────────────┘
           ↓
  ┌─ sdd-spec-writer (Opus) ──────────────────┐
  │  Generate specs for agent tasks           │
  └───────────────────────────────────────────┘
           ↓
  ┌─ {lang}-developer (Sonnet) ┐  ┌─ {lang}-test-engineer (Sonnet) ┐
  │  Implement tasks B, C, D   │  │  Write tests for E, F           │   IN PARALLEL
  └────────────────────────────┘  └─────────────────────────────────┘
           ↓
  ┌─ commit-guardian (Sonnet) ────────────────┐
  │  10 checks: branch → security-guardian →  │
  │  build → tests → format → code-reviewer   │
  │  → README → CLAUDE.md → atomicity →       │
  │  commit message                           │
  │                                           │
  │  If code-reviewer REJECTS:                │
  │    → {lang}-developer fixes               │
  │    → re-build → re-review (max 2x)       │
  │  If all ✅ → git commit                   │
  └───────────────────────────────────────────┘
           ↓
  ┌─ test-runner (Sonnet) ──────────────────┐
  │  Run ALL tests in the project            │
  │  affected by the commit                  │
  │                                          │
  │  If tests fail:                          │
  │    → {lang}-developer fixes (max 2x)     │
  │  If tests pass → verify coverage         │
  │    ≥ TEST_COVERAGE_MIN_PERCENT → ✅     │
  │    < TEST_COVERAGE_MIN_PERCENT →         │
  │      architect (gap analysis) →          │
  │      business-analyst (test cases) →     │
  │      {lang}-developer (implements)       │
  └─────────────────────────────────────────┘
```

## How to invoke agents

```
# Explicitly
"Use the architect agent to analyze if this feature fits the Application layer"
"Use business-analyst and architect in parallel to analyze PBI #1234"

# The correct agent is invoked automatically based on the task description
```
