# Guide: Early-Stage Startup

> Scenario: team of 2–6 people building an MVP. Prioritizes speed, rapid iteration, and validation with real users. No budget for enterprise tools.

---

## Your startup

| Role | Who (sometimes the same person) | Main Commands |
|---|---|---|
| **Founder / CEO** | Vision, prioritization, stakeholders | `/ceo-report`, `/value-stream-map`, `/okr-track` |
| **CTO / Lead Dev** | Architecture, implementation, tech debt | `/arch-detect`, `/debt-analyze`, `/spec-implement` |
| **Fullstack Dev** | Code, features, bugs | `/my-focus`, `/flow-task-move`, `/pr-review` |
| **Product / Design** | UX, discovery, metrics | `/pbi-jtbd`, `/feature-impact`, `/stakeholder-report` |

---

## Why Savia for a startup?

- **Zero cost**: Git + Claude Code. No Jira, Asana, or Linear licenses.
- **Speed**: from idea to executable spec in minutes with SDD.
- **One repo for everything**: code, management, docs, communication.
- **Scales with you**: start with Savia Flow standalone, add Azure DevOps/Jira as you grow.
- **Metrics from day 1**: velocity, DORA, burndown — don't wait to have 50 people to measure.

---

## Setup in 10 minutes

### 1. Clone pm-workspace

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

### 2. Introduce yourself to Savia

> "Hi Savia, I'm the CTO of a startup. We're 3 people building a SaaS inventory management system. We use React + Node.js."

Savia guides you through `/profile-setup` and adapts suggestions to your stack and context.

### 3. Define OKRs (optional but recommended)

> "Savia, define this quarter's OKRs"

```
/okr-define
```

Example:
- **O1**: Launch functional MVP
  - KR1: 5 core features implemented
  - KR2: 10 active beta users
  - KR3: <3s load time

---

## The lean cycle with Savia

### Discovery → PBI

> "Savia, analyze this feature idea with Jobs-to-Be-Done"

```
/pbi-jtbd "Low stock alerts by email"
```

Savia generates: job statement, outcome expectations, and value criteria. This becomes a prioritized PBI.

### PBI → Spec → Implementation

```
/savia-pbi create "Low stock alert by email" --project mvp
/pbi-decompose {id}                  → Tasks with estimation
/spec-generate {task-id}             → Executable SDD spec
/spec-implement {spec}               → Implement (you or Claude agent)
```

**The power of SDD for a startup**: you can delegate implementation to a Claude agent while you talk to customers. The spec guarantees the agent does exactly what you need.

### Validate → Iterate

```
/feature-impact --roi                → Does this feature move the needle?
/okr-track                           → Are we advancing toward our OKRs?
```

---

## Day to day (everyone does everything)

### Morning — 15 min

> "Savia, what's most important today?"

```
/my-focus                            → Your highest priority item
/savia-board mvp                     → Project board
```

### During the day

```
/flow-task-move TASK-005 in-progress → Starting
/spec-implement {spec}               → Implement or delegate to agent
/pr-review                           → Quick review
/flow-task-move TASK-005 done        → Done
```

### Friday — Demo + metrics

> "Savia, generate this week's metrics for retro"

```
/sprint-review                       → What was delivered
/velocity-trend                      → Are we getting faster or slower?
/debt-analyze                        → Are we accumulating debt?
```

---

## When to scale

| Signal | Action |
|---|---|
| >6 people on the team | Add `/jira-connect` or Azure DevOps |
| Investor asks for formal metrics | `/ceo-report --format pptx` |
| Need serious CI/CD | Integrate GitHub Actions + PR Guardian |
| Remote team grows | Enable Company Savia for encrypted communication |

---

## Tips for startups

- Don't over-process. Savia adapts to your pace — if a 1-week sprint works, use it
- Use `/spec-implement` with Claude agents to multiply your development capacity
- Run `/debt-analyze` every 2 weeks to avoid surprises when you need to scale
- Measure from day 1 even if you're 2 people — accumulated data has enormous value
- `/pbi-jtbd` before each new feature — avoid building things nobody needs
