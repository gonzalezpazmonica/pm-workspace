# Quick Command Reference

## Sprint and Reporting
```
/sprint:status [--project]        Sprint status with alerts
/sprint:plan [--project]          Sprint Planning assistant
/sprint:review [--project]        Sprint Review summary
/sprint:retro [--project]         Retrospective with data
/report:hours [--project]         Hours report (Excel)
/report:executive                 Multi-project report (PPT/Word)
/report:capacity [--project]      Capacity status
/team:workload [--project]        Workload by person
/board:flow [--project]           Cycle time and bottlenecks
/kpi:dashboard [--project]        Full KPI dashboard
```

## PBI Decomposition
```
/pbi:decompose {id}               Break down a PBI into tasks
/pbi:decompose-batch {id1,id2}    Break down multiple PBIs
/pbi:assign {pbi_id}              (Re)assign tasks for a PBI
/pbi:plan-sprint                  Full sprint planning
```

## Spec-Driven Development
```
/spec:generate {task_id}          Generate Spec from Azure DevOps Task
/spec:implement {spec_file}       Implement Spec (agent or human)
/spec:review {spec_file}          Review Spec quality or implementation
/spec:status [--project]          Sprint Spec dashboard
/agent:run {spec_file} [--team]   Launch Claude agent on a Spec
```

## Product Discovery
```
/pbi:jtbd {id}                   Generate JTBD (Jobs to be Done) for a PBI
/pbi:prd {id}                    Generate PRD (Product Requirements) for a PBI
```

## Quality and Operations
```
/pr:review [PR]                  Multi-perspective PR review (BA, Dev, QA, Sec, DevOps)
/context:load                    Load session context on startup
/changelog:update                Update CHANGELOG.md from conventional commits
/evaluate:repo [URL]             Security and quality audit of external repo
```

## Team Management
```
/team:onboarding {name}          Personalized onboarding guide (context + code)
/team:evaluate {name}            Interactive competency questionnaire → equipo.md profile
/team:privacy-notice {name}      Mandatory GDPR privacy notice before assessment
```

## Infrastructure and Environments
```
/infra:detect {project} {env}    Detect existing infrastructure
/infra:plan {project} {env}      Generate infrastructure plan
/infra:estimate {project}        Estimate costs per environment
/infra:scale {resource}          Propose scaling (requires human approval)
/infra:status {project}          Current infrastructure status
/env:setup {project}             Configure environments (DEV/PRE/PRO)
/env:promote {project} {s} {d}   Promote between environments (PRE→PRO requires approval)
```

---

## Specialized Agent Team

The workspace includes 23 specialized agents organized in 3 groups, each optimized for its task with the most suitable LLM model:

### Management & Architecture Agents

| Agent | Model | When to use |
|---|---|---|
| `architect` | Opus 4.6 | Multi-language architecture design, layer assignment, technical decisions |
| `business-analyst` | Opus 4.6 | PBI analysis, business rules, acceptance criteria, JTBD, PRD, competency assessment |
| `sdd-spec-writer` | Opus 4.6 | Generation and validation of executable SDD Specs |
| `infrastructure-agent` | Opus 4.6 | IaC (Terraform, CloudFormation, Bicep), detect + plan multi-cloud infrastructure |

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
User: /pbi:plan-sprint --project Alpha

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
