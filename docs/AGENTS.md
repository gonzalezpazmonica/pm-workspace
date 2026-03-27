# Agents — Specialized Orchestration & Implementation

pm-workspace has 33 specialized agents organized into 9 categories. Select by task type using the decision tree below.

## Quick Decision Tree

**If you need to:** → **Use agent:**

- **Architecture design, SOLID principles, layering** → `architect` (Opus 4.6)
- **Extract reglas de negocio, acceptance criteria** → `business-analyst` (Opus 4.6)
- **Write executable specs for developers** → `sdd-spec-writer` (Opus 4.6)
- **Code review, OWASP, design review** → `code-reviewer` (Opus 4.6)
- **Implement C# / .NET** → `dotnet-developer` (Sonnet 4.6)
- **Implement TypeScript, Node.js, NestJS** → `typescript-developer` (Sonnet 4.6)
- **Implement React, Angular, Vue** → `frontend-developer` (Sonnet 4.6)
- **Implement Python FastAPI, Django** → `python-developer` (Sonnet 4.6)
- **Write tests, verify coverage ≥80%** → `test-runner` (Sonnet 4.6)
- **Analyze security: OWASP, CWE, deps** → `security-guardian` (Opus 4.6)
- **Pre-commit checks: branch, tests, format** → `commit-guardian` (Sonnet 4.6)
- **Visual design consistency, wireframes** → `visual-qa-agent` (Sonnet 4.6)

## Agents by Category (33 Total)

### Core PM & Architecture (4)

| Name | Model | Description |
|---|---|---|
| `architect` | Opus 4.6 | System design, layers, interfaces, patterns, CAP theorem |
| `business-analyst` | Opus 4.6 | Extract reglas negocio, decompose PBIs, acceptance criteria |
| `sdd-spec-writer` | Opus 4.6 | Write executable specs from architecture + business rules |
| `dev-orchestrator` | Sonnet 4.6 | Plan dev slices, dependency analysis, context budgets |

### Language-Specific Developers (11)

| Name | Model | Language | Framework |
|---|---|---|---|
| `dotnet-developer` | Sonnet 4.6 | C# | .NET 8, Entity Framework, xUnit |
| `typescript-developer` | Sonnet 4.6 | TypeScript | NestJS, Express, Prisma, Jest |
| `frontend-developer` | Sonnet 4.6 | React/Angular | React 18+, Angular 16+, Next.js, Tailwind |
| `java-developer` | Sonnet 4.6 | Java | Spring Boot 3, JPA, Maven |
| `python-developer` | Sonnet 4.6 | Python | FastAPI, Django, SQLAlchemy, pytest |
| `go-developer` | Sonnet 4.6 | Go | Gin, gRPC, sqlc |
| `rust-developer` | Sonnet 4.6 | Rust | Axum, Tokio, sqlx |
| `php-developer` | Sonnet 4.6 | PHP | Laravel 11, Blade, Eloquent |
| `mobile-developer` | Sonnet 4.6 | Swift/Kotlin/Flutter | iOS, Android, Dart |
| `ruby-developer` | Sonnet 4.6 | Ruby | Rails 7, RSpec, ActiveRecord |
| `cobol-developer` | Opus 4.6 | COBOL | Copybooks, GnuCOBOL, CICS (legacy assistance) |

### Testing & Quality (4)

| Name | Model | Description |
|---|---|---|
| `test-runner` | Sonnet 4.6 | Run all tests, verify coverage ≥80%, orchestrate improvements |
| `frontend-test-runner` | Sonnet 4.6 | E2E tests (Cypress, Playwright), component tests, a11y |
| `code-reviewer` | Opus 4.6 | SOLID, design patterns, code quality, security hotspots |
| `coherence-validator` | Sonnet 4.6 | Output ↔ objective alignment, completeness, consistency |

### Security (3)

| Name | Model | Specialty |
|---|---|---|
| `security-guardian` | Opus 4.6 | Pre-commit: OWASP, CWE Top 25, credential scanning |
| `security-attacker` | Sonnet 4.6 | Red Team: find vulnerabilities (no fixes) |
| `security-defender` | Sonnet 4.6 | Blue Team: propose security patches |
| `security-auditor` | Sonnet 4.6 | Independent evaluation: 0-100 score, gap analysis |

### Infrastructure & DevOps (3)

| Name | Model | Description |
|---|---|---|
| `infrastructure-agent` | Opus 4.6 | Detect, create (tier min), escalate for production |
| `terraform-developer` | Sonnet 4.6 | IaC: writes .tf files (never applies) |
| `diagram-architect` | Sonnet 4.6 | System diagrams: consistency, layering, feature decomposition |

### Observability & Analysis (4)

| Name | Model | Description |
|---|---|---|
| `reflection-validator` | Opus 4.6 | System 2 thinking: assumptions, causal chains, gaps |
| `drift-auditor` | Opus 4.6 | Code ↔ docs ↔ config convergence, detect drift |
| `azure-devops-operator` | Haiku 4.5 | WIQL queries, work items, sprints, capacity |
| `tech-writer` | Haiku 4.5 | README, CHANGELOG, XML docs, technical writing |

### Visual & UX (1)

| Name | Model | Description |
|---|---|---|
| `visual-qa-agent` | Sonnet 4.6 | Wireframe analysis, screenshot comparison, regression detection |

## Workflow Patterns

### SDD (Spec-Driven Development)

```
business-analyst
    ↓ (extract rules)
architect
    ↓ (design)
sdd-spec-writer
    ↓ (write spec)
{lang}-developer ‖ test-runner  (parallel)
    ↓
code-reviewer
    ↓
commit-guardian (pre-commit)
```

### Feature Release

```
business-analyst (decompose PBI)
    ↓
{lang}-developer (implement slice)
    ↓
test-runner (tests + coverage)
    ↓
security-guardian (pre-commit)
    ↓
code-reviewer (approval)
```

### Architecture Review

```
architect (design)
    ↓
reflection-validator (verify assumptions)
    ↓
security-auditor (assess risk)
    ↓
code-reviewer (approve)
```

### Security Audit

```
security-attacker (find issues)
    ↓
security-defender (propose fixes)
    ↓
security-auditor (score 0-100)
```

## Key Properties

### Model Selection

| Complexity | Model | Agents |
|---|---|---|
| **Lightweight** | Haiku 4.5 | azure-devops-operator, tech-writer |
| **Standard** | Sonnet 4.6 | All developers, test-runner, commit-guardian, visual-qa |
| **Complex** | Opus 4.6 | architect, business-analyst, code-reviewer, security (all), orchestrators |

### Context Budget

- **Heavy** (12K tokens): architect, sdd-spec-writer, code-reviewer, security-*
- **Standard** (8K tokens): developers, test-runner, drift-auditor
- **Light** (4K tokens): diagram-architect, azure-devops-operator

### Memory Enabled?

Agents that learn from patterns: architect, code-reviewer, security-guardian, test-runner, drift-auditor, business-analyst, reflection-validator.

## Agent Profile Structure

Each agent has:

```yaml
name: agent-name
role: "Developer|Architect|QA|Security|etc"
model: "claude-opus-4-6|claude-sonnet-4-6|haiku"
description: "One-line purpose"
max_context_tokens: 8000
output_max_tokens: 500
memory: "project|local|none"
capabilities: ["read", "write", "execute"]
```

## Invocation Pattern

Agents are invoked via `/agent-task` command or internal Task tool:

```bash
# Via command
/agent-task architect --project "sala-reservas" --task "Design API layers"

# Via internal tool (from a skill)
bash scripts/invoke-agent.sh "dotnet-developer" "Implement UserService.CreateAsync"
```

## Limitations & Constraints

- **Terraform developer**: Never executes `terraform apply` (human approval required)
- **Infrastructure agent**: Creates only minimal tier (t2.micro, Standard_B1s), escalates to human for production
- **Security agents**: Run in Red Team / Blue Team / Auditor mode independently (no feedback loops)
- **Context isolation**: Each agent gets <12K token budget (fresh load per invocation)
- **Timeout**: Max 120s per agent execution

## See Also

- Command: `/agent-list` — List all agents with brief descriptions
- Command: `/agent-trace` — View recent agent executions
- Skill: `spec-driven-development/SKILL.md` — SDD orchestration
- Rules: `agents-catalog.md` — Complete agent reference
