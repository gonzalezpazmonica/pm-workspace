# Guide: Software Consultancy with Azure DevOps

> Scenario: team of 4–15 people at a consulting firm delivering projects to customers using Azure DevOps for management and CI/CD.

---

## Your team

| Role | Who they are | What they need from Savia |
|---|---|---|
| **PM / Scrum Master** | Coordinates sprints, reports to client | `/sprint-status`, `/report-executive`, `/ceo-report` |
| **Tech Lead** | Technical decisions, code review | `/arch-health`, `/tech-radar`, `/pr-review` |
| **Developers** (3–8) | Implementation | `/my-sprint`, `/my-focus`, `/spec-implement` |
| **QA** | Testing, validation | `/qa-dashboard`, `/testplan-generate` |
| **Product Owner** | Backlog, prioritization | `/value-stream-map`, `/feature-impact` |

---

## Initial setup (day 1)

### 1. Install pm-workspace

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
```

### 2. Configure Azure DevOps

Edit `CLAUDE.md` with your organization:

```
AZURE_DEVOPS_ORG_URL = "https://dev.azure.com/your-organization"
AZURE_DEVOPS_PAT_FILE = "$HOME/.azure/devops-pat"
```

Save your PAT in the specified file (never in the repo).

### 3. First contact with Savia

Open Claude Code and say:

> "Hi, I'm Ana, PM at a software consulting firm. We use Azure DevOps."

Savia will introduce herself and guide you through `/profile-setup` to get to know you: your name, role, projects, schedules, communication preferences.

### 4. Connect your project

> "Connect the sala-reservas project from Azure DevOps"

Savia will run `/devops-validate` to audit the configuration: process template, states, fields, iterations. If there are incompatibilities, it will propose a remediation plan.

### 5. Team onboarding

For each member:

> "Onboard carlos as a senior developer to the sala-reservas project"

Savia will use `/team-onboarding` to create their profile, assess competencies, and assign permissions.

---

## PM's day to day

### Monday — Planning

```
/daily-routine                     → Savia proposes your day's routine
/sprint-status                     → Current sprint status
/backlog-groom --top 10            → Review top 10 items
/pbi-decompose {id}                → Decompose PBI into tasks
/sprint-plan                       → Plan the sprint
```

**Typical conversation:**

> "Savia, how's the current sprint going?"

Savia responds with burndown, remaining capacity, at-risk items and suggestions.

> "Decompose PBI 1234 into tasks and assign them to the team"

Savia analyzes the PBI, generates tasks with hour estimates, and proposes assignments using scoring (expertise × availability × balance × growth).

### Daily standup (09:15)

> "Savia, prepare today's standup"

Savia collects: items moved yesterday, detected blockers, items at risk due to SLA. Generates an executive summary to share in the daily.

### Friday — Review + Retro

```
/sprint-review                     → Summary of deliverables
/sprint-retro                      → Structured retrospective
/report-executive                  → Report for the client
/kpi-dashboard                     → Sprint metrics
```

---

## Developer's day to day

### Starting the day

> "Savia, what should I be working on today?"

Savia runs `/my-focus` and shows you your highest priority item with all context loaded.

### Implementing an SDD spec

```
/spec-generate {task-id}           → Generate spec from task
/spec-design {spec}                → Design the solution
/spec-implement {spec}             → Implement (human or agent)
/spec-review {file}                → Code review
/spec-verify {spec}                → Final verification
```

**Typical conversation:**

> "Savia, generate the spec for task 5678"

Savia creates an executable spec with: context, requirements, acceptance criteria, expected tests, and files to modify. If you're a human developer, use it as a guide. If you delegate to a Claude agent, it executes it automatically.

### PRs and code review

> "Savia, review PR #42"

Savia runs `/pr-review` analyzing: project conventions, tests, security, performance, and generates constructive comments.

---

## Tech Lead's day to day

```
/arch-health --drift               → Detect architectural drift
/tech-radar                        → Status of technology stack
/team-skills-matrix --bus-factor   → Knowledge risks
/incident-postmortem               → Blameless postmortem
/debt-analyze                      → Technical debt hotspots
```

**Typical conversation:**

> "Savia, is there drift in the architecture of the project?"

Savia analyzes the code against detected patterns (Clean, DDD, CQRS...) and reports deviations with prioritized suggestions.

---

## Complete flow: PBI to production

1. **PO creates PBI** in Azure DevOps → Savia detects it with `/backlog-capture`
2. **PM decomposes** → `/pbi-decompose` generates tasks with hours
3. **PM assigns** → `/pbi-assign` with intelligent scoring
4. **Dev generates spec** → `/spec-generate` creates SDD spec
5. **Architect reviews** → `/spec-design` validates the solution
6. **Security review** → `/security-review` analyzes OWASP
7. **Dev implements** → `/spec-implement` (human or agent)
8. **QA validates** → `/testplan-generate` + `/qa-regression-plan`
9. **PR + merge** → `/pr-review` + PR Guardian (automatic CI)
10. **Release** → `/sprint-release-notes` generates notes

---

## Reports for the client

```
/report-executive                  → Weekly report
/ceo-report --format pptx          → Presentation for leadership
/kpi-dora                          → DORA metrics
/velocity-trend                    → Velocity trend
```

> "Savia, generate this week's report for the client in PowerPoint"

Savia creates a `.pptx` with: sprint summary, burndown, completed items, risks, and next steps. All based on real Azure DevOps data.

---

## Tips specific to Azure DevOps

- Savia automatically validates that your project complies with the "ideal Agile" when you connect it
- CI hooks (`pr-guardian.yml`) integrate with Azure Pipelines
- `/pipeline-status` and `/pipeline-run` operate directly against Azure Pipelines
- Connection strings and secrets never go to the repo — use `config.local/`
- Savia detects whether your process template is Agile, Scrum, or CMMI and adapts
