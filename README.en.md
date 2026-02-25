<img width="2160" height="652" alt="image" src="https://github.com/user-attachments/assets/c0b5eb61-2137-4245-b773-0b65b4745dd7" />

**English** · [Versión en español](README.md)

# PM-Workspace — Claude Code + Azure DevOps

[![CI](https://img.shields.io/github/actions/workflow/status/gonzalezpazmonica/pm-workspace/ci.yml?branch=main&label=CI&logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gonzalezpazmonica/pm-workspace?logo=github)](https://github.com/gonzalezpazmonica/pm-workspace/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Contributors](https://img.shields.io/github/contributors/gonzalezpazmonica/pm-workspace)](CONTRIBUTORS.md)

> A .NET project management system built on Scrum, powered by Claude Code as an automated PM/Scrum Master — with the ability to delegate technical implementation to AI agents.

---

## What is this?

This workspace turns Claude Code into an **automated Project Manager / Scrum Master** for .NET projects on Azure DevOps. Its most advanced feature is **Spec-Driven Development (SDD)**: a process in which technical tasks are documented as executable contracts, and Claude can implement them as a coding agent.

**Sprint management:** burndown tracking, team capacity, board status, KPIs, automatic retrospective and review reports in Excel/PowerPoint.

**PBI decomposition:** Claude analyzes the backlog, breaks each PBI into tasks with hour estimates, detects team workload balance, and proposes assignments using a scoring algorithm (expertise × availability × balance × growth).

**Spec-Driven Development:** tasks become executable specifications. A "developer" can be a human or a Claude agent. Claude can automatically implement Command Handlers, EF Core repositories, unit tests, and more — following the spec as a contract.

---

> **💬 EXAMPLE — First five minutes with the workspace**
>
> _Scenario: Monday morning. You open Claude Code for the first time from the `pm-workspace/` root._
>
> **You type:**
> ```
> What projects do I have configured and what can I do?
> ```
>
> **Claude responds:**
> ```
> I have 2 active projects configured:
>   • ProjectAlpha  — 6-person team, sprint 2026-04 active
>   • ProjectBeta   — 4-person team, fixed price, sprint 2026-04 active
>
> I can help you with:
>   Sprint        → /sprint:status, /sprint:plan, /sprint:review, /sprint:retro
>   Reports       → /report:hours, /report:executive, /report:capacity
>   Backlog       → /pbi:decompose, /pbi:plan-sprint, /pbi:assign
>   SDD (agents)  → /spec:generate, /agent:run, /spec:status
>
> Where do you want to start? If it's Monday, I recommend /sprint:status
> to see the current sprint state before the Daily standup.
> ```
>
> **You type:**
> ```
> /sprint:status --project ProjectAlpha
> ```
>
> **Claude responds:**
> ```
> ══════════════════════════════════════════
>   Sprint 2026-04 · ProjectAlpha · Day 6/10
> ══════════════════════════════════════════
>
>   Burndown  ████████░░░░░░░░  40% complete  ⚠️ below plan
>   Sprint goal: Patient Module v2
>
>   Active items (In Progress): 4
>     AB#1021  Create POST /patients endpoint  → Laura S.   [3/5h]
>     AB#1022  Unit tests PatientService       → 🤖 agent   [Running]
>     AB#1023  Allergies table migration       → Diego T.   [0/4h] ⚠️ no progress
>     AB#1024  Swagger annotations             → 🤖 agent   [Done, in Review]
>
>   🔴 Alerts:
>     • AB#1023 has had no movement for 2 days — is it blocked?
>     • Burndown at 40% on day 6 → risk of not completing sprint goal
>     • Current WIP: 4 items (configured limit: 5) ✅
>
>   Remaining capacity: 68 human hours + ~12 agent hours available
> ```

---

## Workspace Structure

```
pm-workspace/
├── CLAUDE.md                    ← Claude Code entry point (global constants)
├── SETUP.md                     ← Step-by-step configuration guide
├── README.md                    ← Spanish version
├── README.en.md                 ← This file (English)
├── .gitignore
│
├── .claude/
│   ├── settings.local.json      ← Claude Code permissions
│   ├── .env                     ← Environment variables (DO NOT commit)
│   ├── mcp.json                 ← Optional MCP configuration
│   │
│   ├── commands/                ← 19 slash commands
│   │   ├── sprint-status.md
│   │   ├── sprint-plan.md
│   │   ├── sprint-review.md
│   │   ├── sprint-retro.md
│   │   ├── report-hours.md
│   │   ├── report-executive.md
│   │   ├── report-capacity.md
│   │   ├── team-workload.md
│   │   ├── board-flow.md
│   │   ├── kpi-dashboard.md
│   │   ├── pbi-decompose.md
│   │   ├── pbi-decompose-batch.md
│   │   ├── pbi-assign.md
│   │   ├── pbi-plan-sprint.md
│   │   ├── spec-generate.md      ← SDD
│   │   ├── spec-implement.md     ← SDD
│   │   ├── spec-review.md        ← SDD
│   │   ├── spec-status.md        ← SDD
│   │   └── agent-run.md          ← SDD
│   │
│   └── skills/                  ← 6 custom skills
│       ├── azure-devops-queries/
│       ├── sprint-management/
│       ├── capacity-planning/
│       ├── time-tracking-report/
│       ├── executive-reporting/
│       ├── pbi-decomposition/
│       │   └── references/
│       │       └── assignment-scoring.md
│       └── spec-driven-development/
│           ├── SKILL.md
│           └── references/
│               ├── spec-template.md         ← Spec template
│               ├── layer-assignment-matrix.md ← What goes to agent vs human
│               └── agent-team-patterns.md   ← Agent team patterns
│
├── docs/
│   ├── reglas-scrum.md
│   ├── politica-estimacion.md
│   ├── kpis-equipo.md
│   ├── plantillas-informes.md
│   └── flujo-trabajo.md         ← Includes section 8: SDD workflow
│
├── projects/
│   ├── project-alpha/
│   │   ├── CLAUDE.md            ← Project constants + SDD config
│   │   ├── equipo.md            ← Human team + Claude agents as developers
│   │   ├── reglas-negocio.md
│   │   ├── source/              ← git clone the repo here
│   │   ├── sprints/
│   │   └── specs/               ← SDD specs
│   │       ├── sdd-metrics.md
│   │       ├── templates/
│   │       └── sprint-YYYY-MM/
│   ├── project-beta/
│   │   └── (same structure)
│   └── sala-reservas/           ← ⚗️ TEST PROJECT (see section below)
│       ├── CLAUDE.md
│       ├── equipo.md            ← 4 devs + PM + Claude agents
│       ├── reglas-negocio.md    ← 16 documented business rules
│       ├── sprints/
│       │   └── sprint-2026-04/
│       │       └── planning.md
│       ├── specs/
│       │   ├── sdd-metrics.md
│       │   └── sprint-2026-04/
│       │       ├── AB101-B3-create-sala-handler.spec.md
│       │       └── AB102-D1-unit-tests-salas.spec.md
│       └── test-data/           ← Azure DevOps API mock JSON
│           ├── mock-workitems.json
│           ├── mock-sprint.json
│           └── mock-capacities.json
│
├── scripts/
│   ├── azdevops-queries.sh      ← Bash: Azure DevOps REST API queries
│   ├── capacity-calculator.py  ← Python: real capacity calculation
│   └── report-generator.js     ← Node.js: Excel/PPT report generation
│
└── output/
    ├── sprints/
    ├── reports/
    ├── executive/
    └── agent-runs/              ← Claude agent execution logs
```

---

## Initial Setup

### Prerequisites

- [Claude Code](https://docs.claude.ai/claude-code) installed and authenticated (`claude --version`)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) with the `az devops` extension
- Node.js ≥ 18 (for reporting scripts)
- Python ≥ 3.10 (for capacity calculator)
- `jq` installed (`apt install jq` / `brew install jq`)

### Step 1 — Azure DevOps PAT

```bash
mkdir -p $HOME/.azure
echo -n "YOUR_PAT_HERE" > $HOME/.azure/devops-pat
chmod 600 $HOME/.azure/devops-pat
```

The PAT needs these scopes: Work Items (Read & Write), Project and Team (Read), Analytics (Read), Code (Read).

```bash
# Verify connectivity
az devops configure --defaults organization=https://dev.azure.com/MY-ORGANIZATION
export AZURE_DEVOPS_EXT_PAT=$(cat $HOME/.azure/devops-pat)
az devops project list --output table
```

### Step 2 — Edit constants

Open `CLAUDE.md` and update the `⚙️ CONFIGURATION CONSTANTS` section. Repeat for `projects/project-alpha/CLAUDE.md` and `projects/project-beta/CLAUDE.md` with project-specific values.

### Step 3 — Install script dependencies

```bash
cd scripts/
npm install
cd ..
```

### Step 4 — Clone source code

```bash
# For SDD to work, the project source code must be available locally
cd projects/project-alpha/source
git clone https://dev.azure.com/YOUR-ORG/ProjectAlpha/_git/project-alpha .
cd ../../..
```

### Step 5 — Verify the connection

```bash
chmod +x scripts/azdevops-queries.sh
./scripts/azdevops-queries.sh sprint ProjectAlpha "ProjectAlpha Team"
```

### Step 6 — Open with Claude Code

```bash
# From the pm-workspace/ root
claude
```

Claude Code will automatically read `CLAUDE.md` and have access to all commands and skills.

---

> **⚙️ EXAMPLE — How a configured CLAUDE.md looks**
>
> _Scenario: You have a project called "ClinicManagement" on Azure DevOps, with team "ClinicManagement Team". Here are the constants in `projects/clinic-management/CLAUDE.md`:_
>
> ```yaml
> PROJECT_NAME            = "ClinicManagement"
> PROJECT_TEAM            = "ClinicManagement Team"
> AZURE_DEVOPS_ORG_URL    = "https://dev.azure.com/mycompany"
> CURRENT_SPRINT_PATH     = "ClinicManagement\\Sprint 2026-04"
> VELOCITY_HISTORICA      = 38   # Average SP from last 5 sprints
> SPRINT_DURATION_DAYS    = 10
> FOCUS_FACTOR            = 0.75
>
> # Team (exact names as they appear in Azure DevOps)
> TEAM_MEMBERS:
>   - name: "Carlos Mendoza"    role: "Tech Lead"   hours_per_day: 6
>   - name: "Laura Sanchez"     role: "Full Stack"  hours_per_day: 7.5
>   - name: "Diego Torres"      role: "Backend"     hours_per_day: 7.5
>   - name: "Ana Morales"       role: "QA"          hours_per_day: 7.5
>
> sdd_config:
>   token_budget_usd: 25
>   agentization_target: 0.60
> ```
>
> **From this point, Claude knows your organization, team, and project.**
> You don't need to repeat this context in every conversation.

---

## How to Use the Workspace

### Sprint Management

Run these commands inside Claude Code:

| Command | Description |
|---------|-------------|
| `/sprint:status` | Sprint status: burndown, active items, WIP alerts |
| `/sprint:plan` | Sprint Planning assistant: capacity + backlog PBI candidates |
| `/sprint:review` | Sprint Review summary: velocity, completed items, demo |
| `/sprint:retro` | Retrospective template with sprint data |

---

> **💬 EXAMPLE — Monday morning before the Daily standup**
>
> _Scenario: Sprint in progress, day 4 of 10. You want to know if the team is on track before the meeting._
>
> **You type:**
> ```
> /sprint:status --project ClinicManagement
> ```
>
> **Claude responds:**
> ```
> ══════════════════════════════════════════════════
>   Sprint 2026-04 · ClinicManagement · Day 4/10
>   Goal: Appointments Module — full CRUD + notifications
> ══════════════════════════════════════════════════
>
>   Burndown (SP)
>   Ideal:  ▓▓▓▓▓▓▓░░░░░░░░░░░░░  38 → 0
>   Actual: ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░  38 → 23 completed  ⚠️
>   → You have 15 SP completed, should be 15.2 → ✅ on track
>
>   In progress (5 items):
>     AB#2041  POST /appointments endpoint       Laura S.    [4/6h] ✅ on time
>     AB#2042  AppointmentValidator FluentVal.   🤖 agent    [done, in review]
>     AB#2043  Unit tests AppointmentService     🤖 agent    [running, 2h]
>     AB#2044  Appointments table migration      Carlos TL   [0/4h] 🔴 no progress
>     AB#2045  GET /appointments?date query      Diego T.    [2/4h] ✅
>
>   🔴 Needs attention:
>     • AB#2044 — Carlos has not logged any progress in 2 days.
>       Risk: if no progress today, the migration may block Laura and Diego.
>       Suggested action: ask in Daily if it's blocked.
>
>   🟡 Warnings:
>     • 3 PBIs still in "New" status, not yet broken down → do you plan to tackle them this sprint?
>     • Ana (QA) has 0h logged this week — confirm she is active
>
>   Remaining capacity: ~72 human hours | ~18 agent hours
>   Completion estimate: 🟡 MODERATE RISK — depends on the migration
> ```
>
> **You type:**
> ```
> Give me the exact talking point for the Daily about AB#2044
> ```
>
> **Claude responds:**
> ```
> For the Daily about AB#2044 (Appointments table migration):
>
> "Carlos, AB#2044 has had no progress for 2 days. Is it blocked?
>  This migration unblocks Laura for the Appointments queries
>  and Diego for the EF Core relationships. If there's an issue
>  with the schema, let's solve it now before it becomes a bottleneck."
>
> If Carlos confirms a blocker, I can help you:
>   a) Redefine the migration scope to make it simpler
>   b) Reassign to someone with more availability this week
>   c) Move AB#2044 to the next sprint and adapt dependencies
> ```

---

> **💬 EXAMPLE — Full Sprint Planning**
>
> _Scenario: It's the Friday before a new sprint. You want to prepare the planning._
>
> **You type:**
> ```
> /sprint:plan --project ClinicManagement
> ```
>
> **Claude responds:**
> ```
> ══════════════════════════════
>   Sprint Planning · 2026-05
>   ClinicManagement Team
> ══════════════════════════════
>
>   SPRINT CAPACITY
>   ┌──────────────────┬───────┬──────────┬────────┬──────────────┐
>   │ Person           │ Days  │ h/day    │ Factor │ Eff. Capacity│
>   ├──────────────────┼───────┼──────────┼────────┼──────────────┤
>   │ Carlos TL        │  9    │  6.0h    │  0.75  │  40.5h       │
>   │ Laura Sanchez    │ 10    │  7.5h    │  0.75  │  56.3h       │
>   │ Diego Torres     │  9    │  7.5h    │  0.75  │  50.6h       │
>   │ Ana Morales (QA) │ 10    │  7.5h    │  0.75  │  56.3h       │
>   │ 🤖 Claude Agent  │  —    │   —      │   —    │  ~35h est.   │
>   └──────────────────┴───────┴──────────┴────────┴──────────────┘
>   Total human: 203.7h | Historical velocity: 38 SP
>
>   PBI CANDIDATES (ordered by backlog priority)
>   ┌──────┬────────────────────────────────────┬─────┬────────┐
>   │  ID  │ Title                              │ SP  │ h est. │
>   ├──────┼────────────────────────────────────┼─────┼────────┤
>   │ #301 │ Appointment email notifications    │  8  │  38h   │
>   │ #302 │ Patient appointment history        │  5  │  24h   │
>   │ #303 │ Room administration panel          │  8  │  36h   │
>   │ #304 │ Export schedule to PDF             │  3  │  14h   │
>   │ #305 │ API pagination for list endpoints  │  2  │   8h   │ ← capacity limit
>   └──────┴────────────────────────────────────┴─────┴────────┘
>   Proposal: #301 + #302 + #304 + #305 = 18 SP / 84h ✅ within capacity
>   (#303 excluded — 36h exceeds remaining capacity)
>
>   Shall I break down these 4 PBIs into tasks with assignments?
> ```

---

### Reports

| Command | Description |
|---------|-------------|
| `/report:hours` | Hours report (Excel, 4 tabs) |
| `/report:executive` | Multi-project executive report (Word + PPT with traffic lights) |
| `/report:capacity` | Team capacity status for the current week |
| `/team:workload` | Workload map by person |
| `/kpi:dashboard` | Full dashboard: velocity, cycle time, lead time, bug escape rate |

---

> **💬 EXAMPLE — Hours report at sprint close**
>
> _Scenario: Last day of the sprint. The client requests the hours report._
>
> **You type:**
> ```
> /report:hours --project ClinicManagement --sprint 2026-04
> ```
>
> **Claude responds:**
> ```
> Generating hours report for Sprint 2026-04...
> [Querying Azure DevOps Work Items and time tracking]
> [Querying sprint capacities and time entries]
>
> ✅ Report generated: output/reports/ClinicManagement-hours-2026-04.xlsx
>
> Executive summary:
>   Planned hours:   203.7h
>   Logged hours:    198.3h (97.3%)
>   Agent hours:      31.5h (real equivalent: ~$19.80 USD)
>
>   By person:
>     Carlos TL   → 39.0h / 40.5h (96%) ✅
>     Laura S.    → 54.5h / 56.3h (97%) ✅
>     Diego T.    → 52.0h / 50.6h (103%) ⚠️ +2.4h over capacity
>     Ana QA      → 52.8h / 56.3h (94%) ✅
>
>   Completed items: 9/11 (18/20 SP — velocity 18 vs historical 38 🔴)
>   Items carried to next sprint: AB#2044, AB#2051
>
> The Excel has 4 tabs: Summary, By person, By PBI, Agents.
> ```
>
> **Note:** The `.xlsx` file can be delivered directly to the client or PMO.

---

> **💬 EXAMPLE — See the team's actual workload this week**
>
> _Scenario: Wednesday. You suspect someone is overloaded._
>
> **You type:**
> ```
> /team:workload --project ClinicManagement
> ```
>
> **Claude responds:**
> ```
> Team workload — current week (Mon 17/03 – Fri 21/03)
>
>   Carlos TL    ██████████░░░░░  68%  [ 20.4h / 30h available ]  🟢
>   Laura S.     █████████████░░  87%  [ 32.8h / 37.5h ]          🟡 high
>   Diego T.     ████████████████ 100% [ 37.5h / 37.5h ]          🔴 no margin
>   Ana QA       ████████░░░░░░░  55%  [ 20.6h / 37.5h ]          🟢 has margin
>   🤖 Agent     ███████░░░░░░░░  48%  [ 3 specs in queue ]       🟢
>
>   ⚠️  Diego Torres is at 100% — cannot absorb unexpected bugs or incidents.
>   💡 Ana has 16.9h available this week. If there are pending QA
>      or documentation tasks, now is the time to assign them.
> ```

---

### PBI Decomposition

The standard process to prepare a sprint:

1. `/pbi:decompose {id}` — Claude analyzes the PBI, its acceptance criteria, and team context, then proposes a task table.
2. Claude asks if you want to create the tasks in Azure DevOps.
3. You confirm and Claude creates them via REST API.

To prepare the full sprint at once: `/pbi:plan-sprint` runs the complete cycle automatically (capacity → PBI selection → decomposition → assignment → creation in AzDO).

**Assignment scoring algorithm:**
```
score = expertise × 0.40 + availability × 0.30 + balance × 0.20 + growth × 0.10
```
Weights are configurable per project in `projects/{project}/CLAUDE.md`.

---

> **💬 EXAMPLE — Break down a PBI with acceptance criteria**
>
> _Scenario: You have PBI AB#302 "Patient appointment history" with 3 acceptance criteria defined in Azure DevOps._
>
> **You type:**
> ```
> /pbi:decompose 302 --project ClinicManagement
> ```
>
> **Claude responds:**
> ```
> Analyzing AB#302 — "Patient appointment history" (5 SP)
>
> Detected acceptance criteria:
>   ✓ The doctor can filter by date range (start–end)
>   ✓ Shows max. 50 results with pagination (cursor-based)
>   ✓ Includes status per appointment: Confirmed / Cancelled / Completed
>
> Detected stack: .NET 8 / Clean Arch / CQRS / EF Core / xUnit
>
> TASK PROPOSAL:
> ┌────┬──────────────────────────────────────────┬──────┬──────┬────────────────┬───────────────┐
> │ #  │ Task                                     │ Hours│ Act. │ Assigned to    │ Developer Type│
> ├────┼──────────────────────────────────────────┼──────┼──────┼────────────────┼───────────────┤
> │ B1 │ HistorialCitasQuery design + DTO         │  3h  │ Dev  │ Carlos TL      │ human         │
> │ B2 │ EF Core: IHistorialCitasRepository       │  2h  │ Dev  │ Diego T.       │ human         │
> │ B3 │ GetHistorialCitasQueryHandler            │  4h  │ Dev  │ 🤖 agent       │ agent:single  │
> │ C1 │ HistorialCitasController (GET endpoint)  │  3h  │ Dev  │ 🤖 agent       │ agent:single  │
> │ C2 │ Cursor-based pagination (middleware)     │  3h  │ Dev  │ Laura S.       │ human         │
> │ D1 │ Unit tests for QueryHandler              │  2h  │ Dev  │ 🤖 agent       │ agent:single  │
> │ D2 │ End-to-end integration test              │  3h  │ QA   │ Ana Morales    │ human         │
> │ E1 │ Code Review                              │  2h  │ Rev  │ Carlos TL      │ human         │
> └────┴──────────────────────────────────────────┴──────┴──────┴────────────────┴───────────────┘
> Total: 22h | Agent: 9h (~$5.40 USD est.) | Human: 13h
>
> Note: Cursor-based pagination (C2) is a new pattern in this project
> → assigned to Laura (Full Stack, more flexible) instead of the agent.
>
> Shall I create these Tasks in Azure DevOps? (Y/N or adjust as needed)
> ```
>
> **You type:**
> ```
> Change C2 to the agent too, Laura already has a heavy load. Create the tasks.
> ```
>
> **Claude responds:**
> ```
> Adjusted: C2 → agent:single (I'll add the reference pagination pattern to the spec).
>
> Creating 8 tasks in Azure DevOps for AB#302...
>   ✅ AB#302-B1 created → assigned to Carlos Mendoza
>   ✅ AB#302-B2 created → assigned to Diego Torres
>   ✅ AB#302-B3 created → assigned to claude-agent (tag: spec-driven)
>   ✅ AB#302-C1 created → assigned to claude-agent (tag: spec-driven)
>   ✅ AB#302-C2 created → assigned to claude-agent (tag: spec-driven)
>   ✅ AB#302-D1 created → assigned to claude-agent-fast (tag: spec-driven)
>   ✅ AB#302-D2 created → assigned to Ana Morales
>   ✅ AB#302-E1 created → assigned to Carlos Mendoza
>
> 8 tasks created. Agent tasks (B3, C1, C2, D1) now have the
> "spec-driven" tag and are ready for /spec:generate whenever you want.
> ```

---

## Spec-Driven Development (SDD)

SDD is the workspace's most advanced feature. It allows technical tasks to be implemented by a human developer **or by a Claude agent**, depending on the type of task.

A Spec is a contract that describes exactly what to implement. If the contract is detailed enough, an agent can implement it without human intervention.

### Developer types

| Type | Who implements | When |
|------|----------------|------|
| `human` | Team developer | Domain logic, migrations, external integrations, Code Review |
| `agent:single` | One Claude agent | Command Handlers, EF Core Repositories, Validators, Unit Tests, DTOs |
| `agent:team` | Implementer + Tester in parallel | Tasks ≥ 6h with production code + tests |

### SDD workflow

```
1. /pbi:decompose → task proposal with "Developer Type" column
2. /spec:generate {task_id} → generates .spec.md file from Azure DevOps
3. /spec:review {spec_file} → validates the spec (quality, completeness)
4. If developer_type = agent:
     /agent:run {spec_file} → agent implements the spec
   If developer_type = human:
     Assign to the developer
5. /spec:review {spec_file} --check-impl → pre-check of generated code
6. Code Review (E1) → ALWAYS human (Tech Lead)
7. PR → merge → Task: Done
```

### The Spec template

Each Spec (`.spec.md`) has 9 sections that eliminate ambiguity:

1. **Header** — Task ID, developer_type, estimate, assigned to
2. **Context and Goal** — why the task exists, relevant acceptance criteria
3. **Technical Contract** — exact class/method signatures, DTOs with types and constraints, dependencies to inject
4. **Business Rules** — table with each rule, its exception, and HTTP code
5. **Test Scenarios** — Given/When/Then for happy path, errors, and edge cases
6. **Files to Create/Modify** — exact list of paths (the agent cannot deviate from this list)
7. **Reference Code** — example of the same pattern in the project
8. **Implementation Status** — agent log, blockers
9. **Pre-Delivery Checklist** — verification before passing to Code Review

### What tasks an agent can do (by default)

The full matrix is in `.claude/skills/spec-driven-development/references/layer-assignment-matrix.md`. Summary for .NET Clean Architecture projects:

**The agent can do:** Application Layer (Command Handlers, Query Handlers, FluentValidation Validators, AutoMapper Profiles, DTOs), Infrastructure (EF Core Repositories, Fluent API Entity Configurations), API (CRUD Controllers, Swagger annotations), Tests (Application Unit Tests when scenarios are in the Spec).

**Always human:** Domain Layer (new aggregate root entities, Domain Services, complex business logic), Database migrations, Authentication/authorization configuration, External system integrations, Code Review (E1) — no exceptions.

---

> **💬 EXAMPLE — Full SDD flow: from task to production code**
>
> _Scenario: Task AB#302-B3 "GetHistorialCitasQueryHandler" is ready for the agent to implement._
>
> **Step 1 — Generate the spec**
>
> **You type:**
> ```
> /spec:generate 302-B3 --project ClinicManagement
> ```
>
> **Claude responds:**
> ```
> Reading AB#302 (parent PBI) and AB#302-B3 (Task)...
> Analyzing existing code in projects/clinic-management/source/...
> → Module: Appointments / Layer: Application / Type: QueryHandler
> → Developer type: agent:single (repeatable pattern, interfaces defined)
>
> Spec generated:
>   projects/clinic-management/specs/sprint-2026-05/AB302-B3-get-historial-citas-handler.spec.md
>
> Preview of the most critical section (Technical Contract):
> ┌─────────────────────────────────────────────────────────────────┐
> │  public sealed class GetHistorialCitasQuery                     │
> │      : IRequest<PagedResult<HistorialCitaDto>>                  │
> │  {                                                              │
> │      public Guid PacienteId { get; init; }                      │
> │      public DateOnly FechaInicio { get; init; }                 │
> │      public DateOnly FechaFin { get; init; }                    │
> │      public string? Cursor { get; init; }   // pagination       │
> │      public int PageSize { get; init; } = 20;                   │
> │  }                                                              │
> └─────────────────────────────────────────────────────────────────┘
>
> Do you want to review the spec before implementing? → /spec:review AB302-B3-...
> ```
>
> **Step 2 — Validate the spec**
>
> **You type:**
> ```
> /spec:review AB302-B3-get-historial-citas-handler.spec.md
> ```
>
> **Claude responds:**
> ```
> Reviewing spec quality...
>
> ✅ Header complete (Task ID, developer_type, estimate, assigned to)
> ✅ Technical contract defined (interfaces, DTOs, dependencies)
> ✅ Business rules documented: 4 rules with exceptions and HTTP codes
> ✅ Test scenarios: 6 scenarios (happy path + invalid dates + patient not found)
> ✅ Files to create listed: 3 files at exact paths
> ✅ Reference code included (GetCitasDelDíaQueryHandler as pattern)
>
> ══════════════════════
>   ✅ SPEC READY
>   You can run /agent:run
> ══════════════════════
> ```
>
> **Step 3 — Launch the agent**
>
> **You type:**
> ```
> /agent:run projects/clinic-management/specs/sprint-2026-05/AB302-B3-get-historial-citas-handler.spec.md
> ```
>
> **Claude responds:**
> ```
> Launching claude-opus-4-6 agent on AB302-B3...
> Live log: output/agent-runs/20260519-094512-AB302-B3-single.log
>
> [09:45:14] Agent started — reading spec and project context
> [09:45:31] Creating GetHistorialCitasQuery.cs
> [09:45:44] Creating GetHistorialCitasQueryHandler.cs
> [09:46:02] Creating HistorialCitaDto.cs + AutoMapper profile
> [09:46:18] Running dotnet build... ✅ 0 errors
> [09:46:35] Running dotnet test --filter "GetHistorial"... 6/6 ✅
> [09:46:41] Agent finished.
>
> ══════════════════════════════════════════════
>   ✅ IMPLEMENTATION COMPLETE
>   Build: OK | Tests: 6/6 | Duration: 87s
>   Estimated cost: ~$0.62 USD
> ══════════════════════════════════════════════
>
> Files created:
>   + Application/Appointments/Queries/GetHistorialCitas/GetHistorialCitasQuery.cs
>   + Application/Appointments/Queries/GetHistorialCitas/GetHistorialCitasQueryHandler.cs
>   + Application/Appointments/Queries/GetHistorialCitas/HistorialCitaDto.cs
>
> ⚠️  IMPORTANT: Code Review (E1) is mandatory before merging.
>    Assign AB#302-E1 to Carlos TL for review.
>
> Shall I update Task AB#302-B3 in Azure DevOps to "In Review" status?
> ```

---

> **💬 EXAMPLE — Sprint spec dashboard**
>
> _Scenario: You want to see the status of all SDD tasks in the sprint at a glance._
>
> **You type:**
> ```
> /spec:status --project ClinicManagement
> ```
>
> **Claude responds:**
> ```
> ══════════════════════════════════════════════════════════════════
>   SDD Status · ClinicManagement · Sprint 2026-05
> ══════════════════════════════════════════════════════════════════
>
>   Task                             Spec         Dev Type     Status   h    Assigned
>   ─────────────────────────────────────────────────────────────────────────────────
>   AB#302-B3 GetHistorialCitas      ✅ ready      agent:single  ✅ done  4h   agent
>   AB#302-C1 HistorialController    ✅ ready      agent:single  🔄 impl  3h   agent
>   AB#302-C2 Cursor pagination      ✅ ready      agent:single  ⏳ queue 3h   agent
>   AB#302-D1 Unit tests handler     ✅ ready      agent:single  ⏳ queue 2h   agent
>   AB#301-B3 SendConfirmationCmd    ⚠️ incomplete agent:single  🚫 blk   4h   agent
>   AB#301-D1 EmailTemplateService   ⏳ pending    agent:single  ⏳ queue 3h   agent
>
>   Summary:
>     Completed: 1 | In progress: 1 | In queue: 3 | Blocked: 1
>     Agent hours saved (completed): 4h (~$2.48 USD)
>     Agent hours estimated (full sprint): 19h (~$11.78 USD est.)
>
>   ⚠️  AB#301-B3 blocked:
>      The spec has an incomplete Technical Contract section —
>      the IEmailService signature is missing. Run /spec:review AB301-B3-...
>      to see exactly what's missing.
> ```

---

### Agent team patterns

For large tasks, you can use a team of agents in parallel:

```bash
/agent:run {spec_file} --team
# Launches: Implementer (opus) + Tester (haiku) in parallel
# Time: ~50% less than sequential
# Cost: ~$0.80-1.80 per spec
```

Available patterns are documented in `references/agent-team-patterns.md`:

- `single` — 1 agent (tasks ≤ 6h)
- `impl-test` — Implementer + Tester in parallel
- `impl-test-review` — adds a Reviewer after the parallel phase
- `full-stack` — 4 agents per layer (API, Application, Infrastructure, Tests)
- `parallel-handlers` — N agents for N specs simultaneously

---

> **💬 EXAMPLE — Launch an agent team for a large task**
>
> _Scenario: Task AB#301-B3 "SendCitaConfirmationCommandHandler" is complex (6h), has production code, and needs tests. You use the `impl-test` pattern._
>
> **You type:**
> ```
> /agent:run projects/clinic-management/specs/sprint-2026-05/AB301-B3-send-confirmation-cmd.spec.md --team
> ```
>
> **Claude responds:**
> ```
> Selected pattern: impl-test (production code + tests in parallel)
>   Agent 1 — Implementer: claude-opus-4-6  (handler + service)
>   Agent 2 — Tester:      claude-haiku-4-5-20251001 (unit tests + mocks)
>
> Estimated cost: ~$1.40 USD
> Confirm launch?
> ```
>
> **You type:**
> ```
> Yes
> ```
>
> **Claude responds:**
> ```
> Launching 2 agents in parallel...
>
> [Agent 1 — opus] 09:51:03 → Implementing SendCitaConfirmationCommandHandler...
> [Agent 2 — haiku] 09:51:04 → Generating unit tests for SendCitaConfirmationCommand...
>
> [Agent 1] 09:52:41 → Handler + EmailTemplateService complete. Build OK.
> [Agent 2] 09:52:58 → 9 unit tests generated. Waiting for implementation to run.
>
> [Syncing] → Running dotnet test... 9/9 ✅
>
> ══════════════════════════════════════════════
>   ✅ TEAM COMPLETE
>   Total duration: 118s (vs ~210s sequential)
>   Build: OK | Tests: 9/9
>   Actual cost: $1.22 USD
> ══════════════════════════════════════════════
> ```

---

## Advanced Per-Project Configuration

Each project has its own `CLAUDE.md` with specific configuration that adapts Claude's behavior to the team's particularities and contract type.

### Assignment weights (pbi-decomposition)

```yaml
# In projects/{project}/CLAUDE.md
assignment_weights:
  expertise:    0.40   # Prioritize whoever knows the module best
  availability: 0.30   # Prioritize whoever has the most free hours
  balance:      0.20   # Distribute load equitably
  growth:       0.10   # Provide learning opportunities
```

For fixed-price projects, you can adjust: higher weight on expertise and availability, `growth: 0.00` to avoid risking the budget.

### SDD configuration

```yaml
# In projects/{project}/CLAUDE.md
sdd_config:
  model_agent: "claude-opus-4-6"
  model_mid:   "claude-sonnet-4-6"
  model_fast:  "claude-haiku-4-5-20251001"
  token_budget_usd: 30          # Monthly token budget
  max_parallel_agents: 5

  # Override the global matrix for this project
  layer_overrides:
    - layer: "Authentication"
      force: "human"
      reason: "Security module — always human review"
```

### Adding a new project

1. Copy `projects/project-alpha/` to `projects/your-project/`
2. Edit `projects/your-project/CLAUDE.md` with the new project constants
3. Add the project to the root `CLAUDE.md` (section `📋 Active Projects`)
4. Clone the repo into `projects/your-project/source/`

---

> **⚙️ EXAMPLE — Fixed-price project with conservative SDD**
>
> _Scenario: "ProjectBeta" is a fixed-price contract. You want to maximize senior team velocity and use agents only for the safest tasks, with no budget risk._
>
> ```yaml
> # projects/project-beta/CLAUDE.md
>
> PROJECT_TYPE = "fixed-price"
>
> assignment_weights:
>   expertise:    0.55   # ← raise: always the best person for each task
>   availability: 0.35   # ← raise: don't overload in fixed-price
>   balance:      0.10
>   growth:       0.00   # ← zero: no learning-time risk
>
> sdd_config:
>   model_agent: "claude-opus-4-6"
>   model_mid:   "claude-sonnet-4-6"
>   model_fast:  "claude-haiku-4-5-20251001"
>   agentization_target: 0.40    # ← conservative goal: only 40% agentized
>   require_tech_lead_approval: true  # ← Carlos reviews EVERY spec before launching agent
>   cost_alert_per_spec_usd: 1.50     # ← alert if a spec exceeds $1.50
>   token_budget_usd: 15              # ← tighter monthly budget
>
>   layer_overrides:
>     - layer: "Domain"       force: "human"  reason: "fixed price — 0 risk"
>     - layer: "Integration"  force: "human"  reason: "client external APIs"
>     - layer: "Migration"    force: "human"  reason: "irreversible DB changes"
> ```
>
> **With this configuration, Claude will automatically:**
> - Propose only the safest tasks to the agent (validators, unit tests, DTOs)
> - Ask Tech Lead approval before launching any agent
> - Warn if the estimated cost of a spec exceeds $1.50
> - Always assign the team member with the most expertise in the module (expertise: 0.55)

---

## Test Project — `sala-reservas`

The workspace includes a **complete test project** (`projects/sala-reservas/`) that lets you verify all functionality without connecting to a real Azure DevOps instance. It uses simulated data (mock JSON) that faithfully mimics the Azure DevOps API structure.

### What is sala-reservas

A simple meeting room booking application: room CRUD (Room) and booking CRUD by date (Booking), no login — the employee enters their name manually. Stack: .NET 8, Clean Architecture, CQRS/MediatR, EF Core.

**Simulated team:** 4 human developers (Tech Lead, Full Stack, Backend, QA) + 1 PM + Claude agent team.

The project includes two complete SDD specs that serve as reference for testing the Spec-Driven Development flow:
- `AB101-B3-create-sala-handler.spec.md` — Command Handlers for Room CRUD (opus agent)
- `AB102-D1-unit-tests-salas.spec.md` — 15 unit tests with xUnit + Moq (haiku agent)

### Running the workspace tests

The `scripts/test-workspace.sh` script validates that the workspace is correctly configured. It runs 96 tests grouped into 9 categories.

#### Mock mode (without Azure DevOps) — recommended to start

```bash
chmod +x scripts/test-workspace.sh
./scripts/test-workspace.sh --mock
```

Expected result: **≥ 93/96 tests pass**. Failures in mock mode are expected and don't indicate workspace issues:
- `az` (Azure CLI) not installed in the test environment
- `node_modules` doesn't exist — run `cd scripts && npm install` to install Node dependencies

#### Real mode (with Azure DevOps configured)

```bash
./scripts/test-workspace.sh --real
```

Requires: PAT configured, `az devops` installed, correct constants in `CLAUDE.md`.

#### Run a specific category

```bash
./scripts/test-workspace.sh --only structure    # File structure only
./scripts/test-workspace.sh --only sdd          # SDD validation only
./scripts/test-workspace.sh --only capacity     # Capacity and formulas only
./scripts/test-workspace.sh --only sprint       # Sprint data only
./scripts/test-workspace.sh --only imputacion   # Hours logging only
./scripts/test-workspace.sh --only report       # Report generation only
./scripts/test-workspace.sh --only backlog      # Backlog and scoring only
```

#### Verbose output

```bash
./scripts/test-workspace.sh --mock --verbose
```

### Test categories and what they validate

| Category | Tests | What it checks |
|----------|-------|----------------|
| `prereqs` | 5 | Installed tools (jq, python3, node, az, claude CLI) |
| `structure` | 18 | Existence of all workspace files |
| `connection` | 8 | Azure DevOps connectivity (`--real` only) |
| `capacity` | 12 | Capacity formulas, assignment scoring algorithm |
| `sprint` | 14 | Sprint data, burndown, valid mock JSON |
| `imputacion` | 10 | Hours logging, agent time entries |
| `sdd` | 15 | Specs, layer matrix, agent patterns, conflict algorithm |
| `report` | 8 | Excel/PPT report generation |
| `backlog` | 6 | Backlog query, decomposition, assignment scoring |

### Results report

When finished, the script automatically generates a Markdown report at `output/test-report-YYYYMMDD-HHMMSS.md` with a results summary, failed tests with root causes, and fix instructions.

### Mock data structure

The files in `projects/sala-reservas/test-data/` simulate real Azure DevOps API responses:

| File | Simulated API | Contents |
|------|--------------|----------|
| `mock-workitems.json` | `GET /_apis/wit/wiql` | 3 PBIs + 12 Tasks with states, assignments, and SDD tags |
| `mock-sprint.json` | `GET /_apis/work/teamsettings/iterations` | Sprint 2026-04 with 10-day burndown, historical velocity |
| `mock-capacities.json` | `GET /_apis/work/teamsettings/iterations/{id}/capacities` | Capacities for 5 members + week 1 time entries |

---

## Tracked Metrics and KPIs

| KPI | Description | OK Threshold |
|-----|-------------|-------------|
| Velocity | Story Points completed per sprint | > average of last 5 sprints |
| Burndown | Progress vs sprint plan | Within ±15% range |
| Cycle Time | Days from "Active" to "Done" | < 5 days (P75) |
| Lead Time | Days from "New" to "Done" | < 12 days (P75) |
| Capacity Utilization | % of capacity used | 70-90% (🟢), >95% (🔴) |
| Sprint Goal Hit Rate | % of sprints that meet the goal | > 75% |
| Bug Escape Rate | Production bugs / total completed | < 5% |
| SDD Agentization | % of technical tasks implemented by agent | Target: > 60% |

---

## Critical Rules

1. **The PAT is never hardcoded** — always `$(cat $AZURE_DEVOPS_PAT_FILE)`
2. **Always filter by IterationPath** in WIQL queries, unless explicitly requested otherwise
3. **Confirm before writing** to Azure DevOps — Claude asks before modifying data
4. **Read the project's CLAUDE.md** before acting on it
5. **The Spec is the contract** — nothing is implemented without an approved spec (neither humans nor agents)
6. **Code Review (E1) is always human** — no exceptions, never delegated to an agent
7. **"If the agent fails, the Spec wasn't good enough"** — improve the spec, don't skip the process
8. **Token budget** — respect the per-project limit before launching agent:team

---

## Adoption Roadmap

| Weeks | Phase | Goal |
|-------|-------|------|
| 1-2 | Setup | Connect to Azure DevOps, try `/sprint:status` |
| 3-4 | Basic management | Iterate with `/sprint:plan`, `/team:workload`, adjust constants |
| 5-6 | Reporting | Activate `/report:hours` and `/report:executive` with real data |
| 7-8 | SDD pilot | Generate first specs, test agent with 1-2 Application Layer tasks |
| 9+ | SDD at scale | Goal: 60%+ of repetitive technical tasks implemented by agents |

---

## Quick Command Reference

### Sprint and Reporting
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

### PBI Decomposition
```
/pbi:decompose {id}               Break down a PBI into tasks
/pbi:decompose-batch {id1,id2}    Break down multiple PBIs
/pbi:assign {pbi_id}              (Re)assign tasks for a PBI
/pbi:plan-sprint                  Full sprint planning
```

### Spec-Driven Development
```
/spec:generate {task_id}          Generate Spec from Azure DevOps Task
/spec:implement {spec_file}       Implement Spec (agent or human)
/spec:review {spec_file}          Review Spec quality or implementation
/spec:status [--project]          Sprint Spec dashboard
/agent:run {spec_file} [--team]   Launch Claude agent on a Spec
```

---

## Specialized Agent Team

The workspace includes 11 subagents that Claude can invoke in parallel or in sequence,
each optimized for its task with the most suitable LLM model:

| Agent | Model | Color | When to use |
|---|---|---|---|
| `architect` | Opus 4.6 | 🔵 blue | .NET architecture design, layer assignment, technical decisions |
| `business-analyst` | Opus 4.6 | 🟣 purple | PBI analysis, business rules, acceptance criteria |
| `sdd-spec-writer` | Opus 4.6 | 🩵 cyan | Generation and validation of executable SDD Specs |
| `code-reviewer` | Opus 4.6 | 🔴 red | Quality gate: security, SOLID, SonarQube rules (`csharp-rules.md`) |
| `security-guardian` | Opus 4.6 | 🔴 red | Security and confidentiality audit before commit |
| `dotnet-developer` | Sonnet 4.6 | 🟢 green | C#/.NET implementation following approved SDD specs |
| `test-engineer` | Sonnet 4.6 | 🟡 yellow | xUnit/NUnit tests, TestContainers, coverage |
| `test-runner` | Sonnet 4.6 | 🟣 magenta | Post-commit: test execution, coverage ≥ `TEST_COVERAGE_MIN_PERCENT`, improvement orchestration |
| `commit-guardian` | Sonnet 4.6 | 🟠 orange | Pre-commit: branch, security, build, tests, code review, README |
| `tech-writer` | Haiku 4.5 | ⚪ white | README, CHANGELOG, C# XML comments, project docs |
| `azure-devops-operator` | Haiku 4.5 | ⬜ bright white | WIQL queries, create/update work items, sprint management |

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
  ┌─ dotnet-developer (Sonnet) ───┐  ┌─ test-engineer (Sonnet) ─┐
  │  Implement tasks B, C, D      │  │  Write tests for E, F     │   IN PARALLEL
  └───────────────────────────────┘  └──────────────────────────┘
           ↓
  ┌─ commit-guardian (Sonnet) ────────────────┐
  │  9 checks: branch → security-guardian →   │
  │  build → tests → format → code-reviewer   │
  │  → README → CLAUDE.md → commit message    │
  │                                           │
  │  If code-reviewer REJECTS:                │
  │    → dotnet-developer fixes               │
  │    → re-build → re-review (max 2x)       │
  │  If all ✅ → git commit                   │
  └───────────────────────────────────────────┘
           ↓
  ┌─ test-runner (Sonnet) ──────────────────┐
  │  Run ALL tests in the project            │
  │  affected by the commit                  │
  │                                          │
  │  If tests fail:                          │
  │    → dotnet-developer fixes (max 2x)     │
  │  If tests pass → verify coverage         │
  │    ≥ TEST_COVERAGE_MIN_PERCENT → ✅     │
  │    < TEST_COVERAGE_MIN_PERCENT →         │
  │      architect (gap analysis) →          │
  │      business-analyst (test cases) →     │
  │      dotnet-developer (implements)       │
  └─────────────────────────────────────────┘
```

### How to invoke agents

```
# Explicitly
"Use the architect agent to analyze if this feature fits the Application layer"
"Use business-analyst and architect in parallel to analyze PBI #1234"

# The correct agent is invoked automatically based on the task description
```

---

## Project Management Coverage for .NET Teams

This section answers a key question for any PM evaluating this tool: what does it cover, what doesn't it cover, and what can never be covered by definition?

### ✅ Covered and simplified

The following classic PM/Scrum Master responsibilities are automated or significantly reduced in effort:

| Responsibility | Coverage | Simplification |
|----------------|----------|----------------|
| Sprint Planning (capacity + PBI selection) | `/sprint:plan` | High — calculates real capacity, proposes PBIs to fill it, and breaks them into tasks with a single command |
| PBI breakdown into tasks | `/pbi:decompose`, `/pbi:decompose-batch` | High — generates task table with estimates, activity, and assignment. Eliminates task refinement meetings |
| Work assignment (load balancing) | `/pbi:assign` + scoring algorithm | High — expertise×availability×balance algorithm removes subjective intuition and guarantees equitable distribution |
| Burndown tracking | `/sprint:status` | High — automatic burndown at any time, with deviation from ideal and completion forecast |
| Team capacity control | `/report:capacity`, `/team:workload` | High — detects individual overload and free days without manual spreadsheets |
| WIP and blocker alerts | `/sprint:status` | High — automatic alerts for stalled items, people at 100%, and WIP over limit |
| Daily standup preparation | `/sprint:status` | Medium — provides exact status and suggests talking points, but the standup itself is human |
| Hours report | `/report:hours` | High — Excel with 4 tabs auto-generated from Azure DevOps, no manual editing |
| Multi-project executive report | `/report:executive` | High — PPT/Word with status traffic lights, ready to send to management |
| Team velocity and KPIs | `/kpi:dashboard` | High — velocity, cycle time, lead time, bug escape rate calculated from real AzDO data |
| Sprint Review preparation | `/sprint:review` | Medium — generates completed items summary and velocity, but the demo is done by the team |
| Sprint Retrospective data | `/sprint:retro` | Medium — provides quantitative sprint data, but the retrospective dynamics are human |
| Repetitive .NET task implementation | SDD + `/agent:run` | Very high — Command Handlers, Repositories, Validators, Unit Tests implemented without human intervention |
| Spec quality control | `/spec:review` | High — automatically validates that a spec has sufficient detail before implementation |

### 🔮 Not yet covered — candidates for the future

Areas that would be naturally automatable with Claude and represent a logical evolution of the workspace:

**Backlog management and refinement:** Claude currently breaks down existing PBIs, but doesn't assist in creating new PBIs from scratch (from client notes, emails, support tickets). A `backlog:capture` skill that converts unstructured inputs into well-formed PBIs with acceptance criteria would be a natural next step.

**Risk management (risk log):** the workspace detects WIP and burndown alerts, but doesn't maintain a structured risk register with probability, impact, and mitigation plans. A `risk:log` skill that updates the register on each `/sprint:status` and escalates critical risks to the PM would be valuable.

**Automatic release notes:** at sprint close, Claude has all the information to generate release notes from completed items and commits. This isn't implemented, but would be a straightforward `/sprint:release-notes` command.

**Technical debt management:** the workspace doesn't track or prioritize technical debt. A skill that analyzes the backlog for items tagged "refactor" or "tech-debt" and proposes them for maintenance sprints would be a useful addition.

**New member onboarding:** when someone new joins the team, Claude could automatically generate a personalized onboarding guide (environment setup, project modules, code conventions) from workspace files.

**Pull request integration:** the workspace manages tasks in AzDO but doesn't track associated PR status (reviewers, pending comments, review time). Integration with Azure DevOps Git API would complete the cycle.

**Production bug tracking:** the bug escape rate is calculated, but there's no automated flow for prioritizing incoming bugs, linking them to the current sprint, and proposing whether they impact the sprint goal.

**Assisted estimation of new PBIs:** Claude could estimate Story Points for a new PBI based on historical similar completed PBIs (semantic analysis of titles and acceptance criteria), reducing dependence on Planning Poker for simple items.

### 🚫 Out of scope for automation — always human

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

## How to Contribute

This project is designed to grow with community contributions. If you use the workspace on a real project and find an improvement, a new command, or a missing skill, your contribution is welcome.

### What types of contributions we accept

**New slash commands** (`.claude/commands/`) — the highest-impact area. If you've automated a Claude conversation that solves a PM problem not yet covered, package it as a command and share it. High-interest examples: `risk:log`, `sprint:release-notes`, `backlog:capture`, `pr:status`.

**New skills** (`.claude/skills/`) — skills that extend Claude's behavior in new areas (technical debt management, Jira integration, Kanban or SAFe methodology support, stacks other than .NET).

**Test project extensions** (`projects/sala-reservas/`) — new mock files, new example specs, new categories in `test-workspace.sh`.

**Documentation fixes and improvements** — clarifications in SKILL.md files, additional examples in the README, translations.

**Script bug fixes** (`scripts/`) — improvements to `azdevops-queries.sh`, `capacity-calculator.py`, or `report-generator.js`.

### Contribution flow

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

### PR acceptance criteria

A PR is accepted if it meets all these criteria and at least one maintainer reviews it:

The test suite continues to pass in mock mode (≥ 93/96). The new command or skill has a name consistent with existing ones (kebab-case, namespace with `:` or `-`). It doesn't include credentials, PATs, internal URLs, or real project data. If it adds a new file that should exist in all projects (like `sdd-metrics.md`), it also adds the corresponding test in `test-workspace.sh`. The inline documentation in the file is sufficient for another PM to understand what it's for without reading the code.

### Reporting a bug or proposing a feature

Open an Issue on GitHub with one of these prefixes in the title:

```
[BUG]     /sprint:status doesn't show alerts when WIP = 0
[FEATURE] Add support for Kanban methodology
[DOCS]    The SDD example in the README doesn't reflect current behavior
[QUESTION] How do I configure the workspace for projects with multiple repos?
```

Always include: Claude Code version used (`claude --version`), which command or skill is involved, what behavior you expected and what you got, and whether it's reproducible with the `sala-reservas` test project in mock mode.

### Code of conduct

Contributions must be respectful, technically sound, and focused on solving real project management problems. Contributions accompanied by a real (anonymized) use case are especially valued, as they demonstrate that the functionality addresses a genuine need.

---

## Support

To adjust Claude's behavior, edit the files in `.claude/skills/` (each skill has its `SKILL.md`) or add new slash commands in `.claude/commands/`.

SDD usage metrics are automatically recorded in `projects/{project}/specs/sdd-metrics.md` when running `/spec:review --check-impl`.

---

*PM-Workspace — Claude Code + Azure DevOps strategy for .NET/Scrum teams*
