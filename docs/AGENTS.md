# Agents — Specialized Orchestration & Implementation

pm-workspace has 33 specialized agents organized into 9 categories. Select by task type using the decision tree below.

## Quick Decision Tree

**If you need to:** → **Use agent:**

- **Architecture design, SOLID principles, layering** → `architect` (Heavy tier: deep reasoning)
- **Extract reglas de negocio, acceptance criteria** → `business-analyst` (Heavy tier)
- **Write executable specs for developers** → `sdd-spec-writer` (Heavy tier)
- **Code review, OWASP, design review** → `code-reviewer` (Heavy tier)
- **Implement C# / .NET** → `dotnet-developer` (Mid tier)
- **Implement TypeScript, Node.js, NestJS** → `typescript-developer` (Mid tier)
- **Implement React, Angular, Vue** → `frontend-developer` (Mid tier)
- **Implement Python FastAPI, Django** → `python-developer` (Mid tier)
- **Write tests, verify coverage ≥80%** → `test-runner` (Mid tier)
- **Analyze security: OWASP, CWE, deps** → `security-guardian` (Heavy tier)
- **Pre-commit checks: branch, tests, format** → `commit-guardian` (Mid tier)
- **Visual design consistency, wireframes** → `visual-qa-agent` (Mid tier)

## Agents by Category (33 Total)

### Core PM & Architecture (4)

| Name | Model | Description |
|---|---|---|
| `architect` | Heavy | System design, layers, interfaces, patterns, CAP theorem |
| `business-analyst` | Heavy | Extract reglas negocio, decompose PBIs, acceptance criteria |
| `sdd-spec-writer` | Heavy | Write executable specs from architecture + business rules |
| `dev-orchestrator` | Mid | Plan dev slices, dependency analysis, context budgets |

### Language-Specific Developers (11)

| Name | Model | Language | Framework |
|---|---|---|---|
| `dotnet-developer` | Mid | C# | .NET 8, Entity Framework, xUnit |
| `typescript-developer` | Mid | TypeScript | NestJS, Express, Prisma, Jest |
| `frontend-developer` | Mid | React/Angular | React 18+, Angular 16+, Next.js, Tailwind |
| `java-developer` | Mid | Java | Spring Boot 3, JPA, Maven |
| `python-developer` | Mid | Python | FastAPI, Django, SQLAlchemy, pytest |
| `go-developer` | Mid | Go | Gin, gRPC, sqlc |
| `rust-developer` | Mid | Rust | Axum, Tokio, sqlx |
| `php-developer` | Mid | PHP | Laravel 11, Blade, Eloquent |
| `mobile-developer` | Mid | Swift/Kotlin/Flutter | iOS, Android, Dart |
| `ruby-developer` | Mid | Ruby | Rails 7, RSpec, ActiveRecord |
| `cobol-developer` | Heavy | COBOL | Copybooks, GnuCOBOL, CICS (legacy assistance) |

### Testing & Quality (4)

| Name | Model | Description |
|---|---|---|
| `test-runner` | Mid | Run all tests, verify coverage ≥80%, orchestrate improvements |
| `frontend-test-runner` | Mid | E2E tests (Cypress, Playwright), component tests, a11y |
| `code-reviewer` | Heavy | SOLID, design patterns, code quality, security hotspots |
| `coherence-validator` | Mid | Output ↔ objective alignment, completeness, consistency |

### Security (3)

| Name | Model | Specialty |
|---|---|---|
| `security-guardian` | Heavy | Pre-commit: OWASP, CWE Top 25, credential scanning |
| `security-attacker` | Mid | Red Team: find vulnerabilities (no fixes) |
| `security-defender` | Mid | Blue Team: propose security patches |
| `security-auditor` | Mid | Independent evaluation: 0-100 score, gap analysis |

### Infrastructure & DevOps (3)

| Name | Model | Description |
|---|---|---|
| `infrastructure-agent` | Heavy | Detect, create (tier min), escalate for production |
| `terraform-developer` | Mid | IaC: writes .tf files (never applies) |
| `diagram-architect` | Mid | System diagrams: consistency, layering, feature decomposition |

### Observability & Analysis (4)

| Name | Model | Description |
|---|---|---|
| `reflection-validator` | Heavy | System 2 thinking: assumptions, causal chains, gaps |
| `drift-auditor` | Heavy | Code ↔ docs ↔ config convergence, detect drift |
| `azure-devops-operator` | Fast | WIQL queries, work items, sprints, capacity |
| `tech-writer` | Fast | README, CHANGELOG, XML docs, technical writing |

### Visual & UX (1)

| Name | Model | Description |
|---|---|---|
| `visual-qa-agent` | Mid | Wireframe analysis, screenshot comparison, regression detection |

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
| **Lightweight** | Fast | azure-devops-operator, tech-writer |
| **Standard** | Mid | All developers, test-runner, commit-guardian, visual-qa |
| **Complex** | Heavy | architect, business-analyst, code-reviewer, security (all), orchestrators |

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
model: "opus|sonnet|haiku"
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
