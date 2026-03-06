# Quick Start — PM / Scrum Master

> 🦉 Hi, PM. I'm Savia. I'll be your copilot for sprint management, team capacity, and reports. Here's the essentials to get started.

---

## First 10 minutes

Open Claude Code at the pm-workspace root and run these three commands:

```
/sprint-status --project MyProject
```
You'll see the burndown, active items, alerts, and remaining capacity for the current sprint.

```
/team-workload --project MyProject
```
Shows each member's load: assigned vs available hours, and detects overloads.

```
/daily-routine
```
I suggest the day's routine based on your role: what to review, in what order, what commands to use.

---

## Your daily routine

**Monday** — `/sprint-status` to set up the week. Blocked items show up in alerts.

**Every morning** — `/async-standup --compile` collects team updates. If someone didn't report, I'll flag it.

**Wednesday** — `/team-workload` mid-sprint to detect deviations. If velocity drops and hours rise, it could be burnout → `/wellbeing-check`.

**Closing Friday** — `/sprint-review` generates the summary. `/sprint-retro` structures the retrospective with detected patterns.

**End of sprint** — `/report-hours` exports time tracking to Excel. `/report-executive` generates the report for leadership.

---

## How to talk to me

You don't need to memorize commands. You can ask me things in natural language:

| You say... | I run... |
|---|---|
| "How's the sprint going?" | `/sprint-status` |
| "Who's overloaded?" | `/team-workload` + capacity analysis |
| "I need the client report" | `/report-executive` or `/excel-report` |
| "Prepare tomorrow's daily" | `/async-standup --start` |
| "Break down this PBI into tasks" | `/pbi-decompose {id}` |
| "Will we finish the sprint?" | `/sprint-forecast` with Monte Carlo |

---

## Where your files are

```
output/
├── reports/           ← generated reports (Excel, PowerPoint)
├── sprint-snapshots/  ← sprint state snapshots
└── .memory-store.jsonl ← my persistent memory

.claude/commands/
├── sprint-*.md        ← sprint commands (plan, status, review, retro)
├── report-*.md        ← reporting commands
├── team-*.md          ← team and capacity commands
└── pbi-*.md           ← backlog management
```

Reports are generated in `output/` with dates in the filename. You can open them directly or send them.

---

## How your work connects

The hours your team logs (`/report-hours`) feed into project costs (`cost-management`). Those costs generate invoices and show up in the executive report (`/ceo-report`). If velocity drops and hours increase, I trigger burnout alerts that the CEO sees in `/ceo-alerts`. Everything is connected — your work as PM is the data entry point that feeds the entire chain.

---

## Next steps

- [Sprints and reports in detail](../readme_en/04-uso-sprint-informes.md)
- [Advanced configuration](../readme_en/06-configuracion-avanzada.md)
- [Data flow guide](../data-flow-guide-en.md)
- [Full commands and agents](../readme/12-comandos-agentes.md)
