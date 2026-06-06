# How to Use the Workspace

## Sprint Management

Run these commands inside Claude Code / OpenCode:

| Command | Description |
|---------|-------------|
| `/sprint-status` | Sprint status: burndown, active items, WIP alerts |
| `/sprint-plan` | Sprint Planning assistant: capacity + backlog PBI candidates |
| `/sprint-review` | Sprint Review summary: velocity, completed items, demo |
| `/sprint-retro` | Retrospective template with sprint data |

---

## EXAMPLE — Monday morning before the Daily standup

_Scenario: Sprint in progress, day 4 of 10. You want to know if the team is on track before the meeting._

**You type:**
```
/sprint-status --project ClinicManagement
```

**Claude responds:**
```
══════════════════════════════════════════════════
  Sprint 2026-04 · ClinicManagement · Day 4/10
  Goal: Appointments Module — full CRUD + notifications
══════════════════════════════════════════════════

  Burndown (SP)
  Ideal:  ▓▓▓▓▓▓▓░░░░░░░░░░░░░  38 → 0
  Actual: ▓▓▓▓▓▓▓▓▓░░░░░░░░░░░  38 → 23 completed  ⚠️
  → You have 15 SP completed, should be 15.2 → ✅ on track

  In progress (5 items):
    AB#2041  POST /appointments endpoint       Laura S.    [4/6h] ✅ on time
    AB#2042  AppointmentValidator FluentVal.   🤖 agent    [done, in review]
    AB#2043  Unit tests AppointmentService     🤖 agent    [running, 2h]
    AB#2044  Appointments table migration      Carlos TL   [0/4h] 🔴 no progress
    AB#2045  GET /appointments?date query      Diego T.    [2/4h] ✅

  🔴 Needs attention:
    • AB#2044 — Carlos has not logged any progress in 2 days.
      Risk: if no progress today, the migration may block Laura and Diego.
      Suggested action: ask in Daily if it's blocked.

  🟡 Warnings:
    • 3 PBIs still in "New" status, not yet broken down → do you plan to tackle them this sprint?
    • Ana (QA) has 0h logged this week — confirm she is active

  Remaining capacity: ~72 human hours | ~18 agent hours
  Completion estimate: 🟡 MODERATE RISK — depends on the migration
```

**You type:**
```
Give me the exact talking point for the Daily about AB#2044
```

**Claude responds:**
```
For the Daily about AB#2044 (Appointments table migration):

"Carlos, AB#2044 has had no progress for 2 days. Is it blocked?
 This migration unblocks Laura for the Appointments queries
 and Diego for the EF Core relationships. If there's an issue
 with the schema, let's solve it now before it becomes a bottleneck."

If Carlos confirms a blocker, I can help you:
  a) Redefine the migration scope to make it simpler
  b) Reassign to someone with more availability this week
  c) Move AB#2044 to the next sprint and adapt dependencies
```

---

## EXAMPLE — Full Sprint Planning

_Scenario: It's the Friday before a new sprint. You want to prepare the planning._

**You type:**
```
/sprint-plan --project ClinicManagement
```

**Claude responds:**
```
══════════════════════════════
  Sprint Planning · 2026-05
  ClinicManagement Team
══════════════════════════════

  SPRINT CAPACITY
  ┌──────────────────┬───────┬──────────┬────────┬──────────────┐
  │ Person           │ Days  │ h/day    │ Factor │ Eff. Capacity│
  ├──────────────────┼───────┼──────────┼────────┼──────────────┤
  │ Carlos TL        │  9    │  6.0h    │  0.75  │  40.5h       │
  │ Laura Sanchez    │ 10    │  7.5h    │  0.75  │  56.3h       │
  │ Diego Torres     │  9    │  7.5h    │  0.75  │  50.6h       │
  │ Ana Morales (QA) │ 10    │  7.5h    │  0.75  │  56.3h       │
  │ 🤖 Claude Agent  │  —    │   —      │   —    │  ~35h est.   │
  └──────────────────┴───────┴──────────┴────────┴──────────────┘
  Total human: 203.7h | Historical velocity: 38 SP

  PBI CANDIDATES (ordered by backlog priority)
  ┌──────┬────────────────────────────────────┬─────┬────────┐
  │  ID  │ Title                              │ SP  │ h est. │
  ├──────┼────────────────────────────────────┼─────┼────────┤
  │ #301 │ Appointment email notifications    │  8  │  38h   │
  │ #302 │ Patient appointment history        │  5  │  24h   │
  │ #303 │ Room administration panel          │  8  │  36h   │
  │ #304 │ Export schedule to PDF             │  3  │  14h   │
  │ #305 │ API pagination for list endpoints  │  2  │   8h   │ ← capacity limit
  └──────┴────────────────────────────────────┴─────┴────────┘
  Proposal: #301 + #302 + #304 + #305 = 18 SP / 84h ✅ within capacity
  (#303 excluded — 36h exceeds remaining capacity)

  Shall I break down these 4 PBIs into tasks with assignments?
```

---

## Reports

| Command | Description |
|---------|-------------|
| `/report-hours` | Hours report (Excel, 4 tabs) |
| `/report-executive` | Multi-project executive report (Word + PPT with traffic lights) |
| `/report-capacity` | Team capacity status for the current week |
| `/team-workload` | Workload map by person |
| `/kpi-dashboard` | Full dashboard: velocity, cycle time, lead time, bug escape rate |

---

## EXAMPLE — Hours report at sprint close

_Scenario: Last day of the sprint. The client requests the hours report._

**You type:**
```
/report-hours --project ClinicManagement --sprint 2026-04
```

**Claude responds:**
```
Generating hours report for Sprint 2026-04...
[Querying Azure DevOps Work Items and time tracking]
[Querying sprint capacities and time entries]

✅ Report generated: output/reports/ClinicManagement-hours-2026-04.xlsx

Executive summary:
  Planned hours:   203.7h
  Logged hours:    198.3h (97.3%)
  Agent hours:      31.5h (real equivalent: ~$19.80 USD)

  By person:
    Carlos TL   → 39.0h / 40.5h (96%) ✅
    Laura S.    → 54.5h / 56.3h (97%) ✅
    Diego T.    → 52.0h / 50.6h (103%) ⚠️ +2.4h over capacity
    Ana QA      → 52.8h / 56.3h (94%) ✅

  Completed items: 9/11 (18/20 SP — velocity 18 vs historical 38 🔴)
  Items carried to next sprint: AB#2044, AB#2051

The Excel has 4 tabs: Summary, By person, By PBI, Agents.
```

**Note:** The `.xlsx` file can be delivered directly to the client or PMO.

---

## EXAMPLE — See the team's actual workload this week

_Scenario: Wednesday. You suspect someone is overloaded._

**You type:**
```
/team-workload --project ClinicManagement
```

**Claude responds:**
```
Team workload — current week (Mon 17/03 – Fri 21/03)

  Carlos TL    ██████████░░░░░  68%  [ 20.4h / 30h available ]  🟢
  Laura S.     █████████████░░  87%  [ 32.8h / 37.5h ]          🟡 high
  Diego T.     ████████████████ 100% [ 37.5h / 37.5h ]          🔴 no margin
  Ana QA       ████████░░░░░░░  55%  [ 20.6h / 37.5h ]          🟢 has margin
  🤖 Agent     ███████░░░░░░░░  48%  [ 3 specs in queue ]       🟢

  ⚠️  Diego Torres is at 100% — cannot absorb unexpected bugs or incidents.
  💡 Ana has 16.9h available this week. If there are pending QA
     or documentation tasks, now is the time to assign them.
```

---

## PBI Decomposition

The standard process to prepare a sprint:

1. `/pbi-decompose {id}` — Claude analyzes the PBI, its acceptance criteria, and team context, then proposes a task table.
2. Claude asks if you want to create the tasks in Azure DevOps.
3. You confirm and Claude creates them via REST API.

To prepare the full sprint at once: `/pbi-plan-sprint` runs the complete cycle automatically (capacity → PBI selection → decomposition → assignment → creation in AzDO).

**Assignment scoring algorithm:**
```
score = expertise × 0.40 + availability × 0.30 + balance × 0.20 + growth × 0.10
```
Weights are configurable per project in `projects/{project}/CLAUDE.md`.

---

## EXAMPLE — Break down a PBI with acceptance criteria

_Scenario: You have PBI AB#302 "Patient appointment history" with 3 acceptance criteria defined in Azure DevOps._

**You type:**
```
/pbi-decompose 302 --project ClinicManagement
```

**Claude responds:**
```
Analyzing AB#302 — "Patient appointment history" (5 SP)

Detected acceptance criteria:
  ✓ The doctor can filter by date range (start–end)
  ✓ Shows max. 50 results with pagination (cursor-based)
  ✓ Includes status per appointment: Confirmed / Cancelled / Completed

Detected stack: .NET 8 / Clean Arch / CQRS / EF Core / xUnit

TASK PROPOSAL:
┌────┬──────────────────────────────────────────┬──────┬──────┬────────────────┬───────────────┐
│ #  │ Task                                     │ Hours│ Act. │ Assigned to    │ Developer Type│
├────┼──────────────────────────────────────────┼──────┼──────┼────────────────┼───────────────┤
│ B1 │ HistorialCitasQuery design + DTO         │  3h  │ Dev  │ Carlos TL      │ human         │
│ B2 │ EF Core: IHistorialCitasRepository       │  2h  │ Dev  │ Diego T.       │ human         │
│ B3 │ GetHistorialCitasQueryHandler            │  4h  │ Dev  │ 🤖 agent       │ agent-single  │
│ C1 │ HistorialCitasController (GET endpoint)  │  3h  │ Dev  │ 🤖 agent       │ agent-single  │
│ C2 │ Cursor-based pagination (middleware)     │  3h  │ Dev  │ Laura S.       │ human         │
│ D1 │ Unit tests for QueryHandler              │  2h  │ Dev  │ 🤖 agent       │ agent-single  │
│ D2 │ End-to-end integration test              │  3h  │ QA   │ Ana Morales    │ human         │
│ E1 │ Code Review                              │  2h  │ Rev  │ Carlos TL      │ human         │
└────┴──────────────────────────────────────────┴──────┴──────┴────────────────┴───────────────┘
Total: 22h | Agent: 9h (~$5.40 USD est.) | Human: 13h

Note: Cursor-based pagination (C2) is a new pattern in this project
→ assigned to Laura (Full Stack, more flexible) instead of the agent.

Shall I create these Tasks in Azure DevOps? (Y/N or adjust as needed)
```

**You type:**
```
Change C2 to the agent too, Laura already has a heavy load. Create the tasks.
```

**Claude responds:**
```
Adjusted: C2 → agent-single (I'll add the reference pagination pattern to the spec).

Creating 8 tasks in Azure DevOps for AB#302...
  ✅ AB#302-B1 created → assigned to Carlos Mendoza
  ✅ AB#302-B2 created → assigned to Diego Torres
  ✅ AB#302-B3 created → assigned to claude-agent (tag: spec-driven)
  ✅ AB#302-C1 created → assigned to claude-agent (tag: spec-driven)
  ✅ AB#302-C2 created → assigned to claude-agent (tag: spec-driven)
  ✅ AB#302-D1 created → assigned to claude-agent-fast (tag: spec-driven)
  ✅ AB#302-D2 created → assigned to Ana Morales
  ✅ AB#302-E1 created → assigned to Carlos Mendoza

8 tasks created. Agent tasks (B3, C1, C2, D1) now have the
"spec-driven" tag and are ready for /spec-generate whenever you want.
```
