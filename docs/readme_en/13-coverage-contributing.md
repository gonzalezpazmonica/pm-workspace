# Workspace Coverage for Project Management

This section answers a key question for any PM evaluating this tool: what does it cover, what doesn't it cover, and what can never be covered by definition?

## ✅ Covered and simplified

The following classic PM/Scrum Master responsibilities are automated or significantly reduced in effort:

| Responsibility | Coverage | Simplification |
|----------------|----------|----------------|
| Sprint Planning (capacity + PBI selection) | `/sprint-plan` | High — calculates real capacity, proposes PBIs to fill it, and breaks them into tasks with a single command |
| PBI breakdown into tasks | `/pbi-decompose`, `/pbi-decompose-batch` | High — generates task table with estimates, activity, and assignment. Eliminates task refinement meetings |
| Work assignment (load balancing) | `/pbi-assign` + scoring algorithm | High — expertise×availability×balance algorithm removes subjective intuition and guarantees equitable distribution |
| Burndown tracking | `/sprint-status` | High — automatic burndown at any time, with deviation from ideal and completion forecast |
| Team capacity control | `/report-capacity`, `/team-workload` | High — detects individual overload and free days without manual spreadsheets |
| WIP and blocker alerts | `/sprint-status` | High — automatic alerts for stalled items, people at 100%, and WIP over limit |
| Daily standup preparation | `/sprint-status` | Medium — provides exact status and suggests talking points, but the standup itself is human |
| Hours report | `/report-hours` | High — Excel with 4 tabs auto-generated from Azure DevOps, no manual editing |
| Multi-project executive report | `/report-executive` | High — PPT/Word with status traffic lights, ready to send to management |
| Team velocity and KPIs | `/kpi-dashboard` | High — velocity, cycle time, lead time, bug escape rate calculated from real AzDO data |
| Sprint Review preparation | `/sprint-review` | Medium — generates completed items summary and velocity, but the demo is done by the team |
| Sprint Retrospective data | `/sprint-retro` | Medium — provides quantitative sprint data, but the retrospective dynamics are human |
| Repetitive multi-language task implementation | SDD + `/agent-run` | Very high — handlers, repositories, validators, unit tests implemented in 16 languages without human intervention |
| Spec quality control | `/spec-review` | High — automatically validates that a spec has sufficient detail before implementation |
| New member onboarding | `/team-onboarding`, `/team-evaluate` | High — personalized onboarding guide + 26-competency questionnaire with GDPR compliance |
| Infrastructure planning and cost estimation | `/infra-plan`, `/infra-estimate` | High — multi-cloud infrastructure as code with automatic detection and cost analysis |
| Multi-environment management | `/env-setup`, `/env-promote` | High — DEV/PRE/PRO environments with confidential configuration protection |

## 🔮 Not yet covered — candidates for the future

Areas that would be naturally automatable with Claude and represent a logical evolution of the workspace:

**Backlog management and refinement:** Claude currently breaks down existing PBIs, but doesn't assist in creating new PBIs from scratch (from client notes, emails, support tickets). A `backlog-capture` skill that converts unstructured inputs into well-formed PBIs with acceptance criteria would be a natural next step.

**Risk management (risk log):** the workspace detects WIP and burndown alerts, but doesn't maintain a structured risk register with probability, impact, and mitigation plans. A `risk-log` skill that updates the register on each `/sprint-status` and escalates critical risks to the PM would be valuable.

**Automatic release notes:** at sprint close, Claude has all the information to generate release notes from completed items and commits. The `/changelog-update` command partially covers this (generates CHANGELOG from commits), but a dedicated `/sprint-release-notes` that combines commits + work items would be the next step.

**Technical debt management:** the workspace doesn't track or prioritize technical debt. A skill that analyzes the backlog for items tagged "refactor" or "tech-debt" and proposes them for maintenance sprints would be a useful addition.

**Pull request integration:** the `/pr-review` command now covers multi-perspective review of PRs, but the workspace doesn't yet track associated PR status in AzDO (reviewers, pending comments, review time). Full integration with Azure DevOps Git API would complete the cycle.

**Production bug tracking:** the bug escape rate is calculated, but there's no automated flow for prioritizing incoming bugs, linking them to the current sprint, and proposing whether they impact the sprint goal.

**Assisted estimation of new PBIs:** Claude could estimate Story Points for a new PBI based on historical similar completed PBIs (semantic analysis of titles and acceptance criteria), reducing dependence on Planning Poker for simple items.

## 🚫 Out of scope for automation — always human

These responsibilities cannot and should not be delegated to an agent for structural reasons: they require contextual judgment, formal accountability, human relationships, or strategic decisions that cannot be codified in a spec or prompt.

**Architecture decisions** — Choosing between microservices and monolith, deciding whether to adopt Event Sourcing, evaluating an ORM or cloud provider change. These decisions have multi-year implications and require business, team, and contextual understanding that no agent possesses. Claude can inform and analyze options, but cannot and should not decide.

**Real Code Review** — Code Review (E1 in the SDD flow) is inviolably human. An agent can do a build and tests pre-check, but the review of quality, readability, architectural coherence, and subtle security or performance issues requires a senior developer with system context.

**People management** — Performance evaluations, difficult conversations about productivity, promotion decisions, conflict management between team members, hiring and firing. No burndown or capacity data replaces human judgment in these situations.

**Client or stakeholder negotiation** — The workspace generates reports and provides data, but scope negotiation, expectation management, and communicating bad news (a sprint that won't close, a critical production bug) require the presence, empathy, and authority of a real PM.

**Security and compliance decisions** — Reviewing that code complies with GDPR, evaluating the scope of a security breach, deciding if a module needs penetration testing, obtaining quality certifications. These decisions carry legal responsibility that cannot fall on an agent.

**Production database migrations** — The workspace explicitly excludes migrations from the agent scope. Reversibility, the rollback plan, and the maintenance window of a production migration must be in the hands of a developer who understands the actual state of the data.

**User Acceptance Testing (UAT)** — Unit and integration tests can be automated. Validating that the software solves the actual end-user problem cannot. UAT requires real users, business context, and judgment beyond a Given/When/Then scenario.

**Production incident management (P0/P1)** — When something fails in production, triage, crisis communication, the rollback decision, and coordination between teams require an available human with authority and full context of the production system.

**Product vision and roadmap definition** — The workspace manages sprints, not product strategy. What to build, why, and in what order is a business decision that belongs to the Product Owner, CEO, or client — not to an automation system.

---

# How to Contribute

This project is designed to grow with community contributions. If you use the workspace on a real project and find an improvement, a new command, or a missing skill, your contribution is welcome.

## What types of contributions we accept

**New slash commands** (`.claude/commands/`) — the highest-impact area. If you've automated a Claude conversation that solves a PM problem not yet covered, package it as a command and share it. High-interest examples: `risk-log`, `sprint-release-notes`, `backlog-capture`.

**New skills** (`.claude/skills/`) — skills that extend Claude's behavior in new areas (technical debt management, Jira integration, Kanban or SAFe methodology support, new cloud providers).

**Test project extensions** (`projects/sala-reservas/`) — new mock files, new example specs, new categories in `test-workspace.sh`.

**Documentation fixes and improvements** — clarifications in SKILL.md files, additional examples in the README, translations.

**Script bug fixes** (`scripts/`) — improvements to `azdevops-queries.sh`, `capacity-calculator.py`, or `report-generator.js`.

## Contribution flow

```
1. Fork the repository on GitHub
2. Create a branch with a descriptive name
3. Develop and document your contribution
4. Run the test suite (must pass ≥ 93/96 in mock mode)
5. Open a Pull Request using the template
```

**Step 1 — Fork and branch**

```bash
# From your GitHub account, fork the repository
# Then clone your fork and create your working branch:

git clone https://github.com/YOUR-USERNAME/pm-workspace.git
cd pm-workspace
git checkout -b feature/sprint-release-notes
# or for fixes: git checkout -b fix/capacity-formula-edge-case
```

Branch naming conventions:
- `feature/` — new functionality (command, skill, integration)
- `fix/` — bug fix
- `docs/` — documentation only
- `test/` — improvements to the test suite or mock data
- `refactor/` — reorganization without behavior change

**Step 2 — Develop your contribution**

If you add a new slash command, follow the structure of the existing ones in `.claude/commands/`. Each command must include:
- Description of purpose in the first lines
- Numbered steps for the process Claude should follow
- Handling of the most common error case
- At least one usage example in the file itself

If you add a new skill, include a `SKILL.md` with the description, when to use it, configuration parameters, and references to relevant documentation.

**Step 3 — Verify that tests still pass**

```bash
chmod +x scripts/test-workspace.sh
./scripts/test-workspace.sh --mock

# Expected result: ≥ 93/96 PASSED
# If your contribution adds new files that should exist in all projects,
# also add the corresponding tests in the appropriate suite of scripts/test-workspace.sh
```

**Step 4 — Open the Pull Request**

Use this template for the PR body:

```markdown
## What does this PR add or fix?
[Description in 2-3 sentences]

## Contribution type
- [ ] New slash command
- [ ] New skill
- [ ] Bug fix
- [ ] Documentation improvement
- [ ] Test suite extension
- [ ] Other: ___

## Modified / created files
- `.claude/commands/command-name.md` — [what it does]
- `docs/` — [if applicable]

## Tests
- [ ] `./scripts/test-workspace.sh --mock` passes ≥ 93/96
- [ ] I added tests for new files (if applicable)

## Checklist
- [ ] The command/skill follows the style conventions of existing ones
- [ ] I tested the conversation with Claude manually at least once
- [ ] I don't include real project data, client info, or PATs
```

## PR acceptance criteria

A PR is accepted if it meets all these criteria and at least one maintainer reviews it:

The test suite continues to pass in mock mode (≥ 93/96). The new command or skill has a name consistent with existing ones (kebab-case, namespace with `:` or `-`). It doesn't include credentials, PATs, internal URLs, or real project data. If it adds a new file that should exist in all projects (like `sdd-metrics.md`), it also adds the corresponding test in `test-workspace.sh`. The inline documentation in the file is sufficient for another PM to understand what it's for without reading the code.

## Reporting a bug or proposing a feature

Open an Issue on GitHub with one of these prefixes in the title:

```
[BUG]     /sprint-status doesn't show alerts when WIP = 0
[FEATURE] Add support for Kanban methodology
[DOCS]    The SDD example in the README doesn't reflect current behavior
[QUESTION] How do I configure the workspace for projects with multiple repos?
```

Always include: Claude Code version used (`claude --version`), which command or skill is involved, what behavior you expected and what you got, and whether it's reproducible with the `sala-reservas` test project in mock mode.

## Code of conduct

Contributions must be respectful, technically sound, and focused on solving real project management problems. Contributions accompanied by a real (anonymized) use case are especially valued, as they demonstrate that the functionality addresses a genuine need.

---

## Support

To adjust Claude's behavior, edit the files in `.claude/skills/` (each skill has its `SKILL.md`) or add new slash commands in `.claude/commands/`.

SDD usage metrics are automatically recorded in `projects/{project}/specs/sdd-metrics.md` when running `/spec-review --check-impl`.

---

*PM-Workspace — Claude Code + Azure DevOps strategy for multi-language/Scrum teams with cloud infrastructure support*
