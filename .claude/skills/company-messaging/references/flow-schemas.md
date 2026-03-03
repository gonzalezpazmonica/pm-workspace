# Savia Flow — YAML Schemas Reference

> Schemas for PBI, Sprint, Timesheet, and Team files stored in the company repo.

---

## PBI Schema (`projects/{name}/backlog/pbi-NNN.md`)

```yaml
---
id: "PBI-001"                          # Auto-incremented
title: "Feature description"           # Short title
status: "new"                          # new|ready|in-progress|review|done
priority: "medium"                     # low|medium|high|critical
estimate: 5                            # Story points (integer)
assignee: "alice"                      # @handle or empty
created_by: "bob"                      # @handle of creator
created_date: "2026-03-03T10:00:00Z"   # ISO 8601 UTC
sprint: "sprint-2026-01"               # Sprint name or empty
tags: ["frontend", "auth"]             # Array of labels
---
Description in markdown below frontmatter.
```

### State Machine

```
new → ready → in-progress → review → done (archived)
```

When moved to `done`, the file is moved to `backlog/archive/`.

---

## Sprint Schema (`projects/{name}/sprints/{sprint}/sprint.md`)

```yaml
---
name: "sprint-2026-01"                 # Unique sprint name
goal: "Deliver MVP login flow"         # Sprint goal
status: "active"                       # active|closed
start_date: "2026-03-03"              # ISO date
end_date: "2026-03-14"                # ISO date
created_date: "2026-03-03T10:00:00Z"  # ISO 8601 UTC
---
```

The `sprints/current.md` file points to the active sprint:
```
current: sprint-2026-01
```

---

## Timesheet Schema (`team/{handle}/savia-flow/timesheet/YYYY-MM.md`)

```markdown
# Timesheet — @handle — 2026-03

## 2026-03-03
- pbi: "PBI-001"
  hours: 4
  project: "alpha"
  description: "Frontend work"
```

Monthly file, entries appended daily. One heading per day.

---

## Team Schema (`teams/{team}/team.md`)

```yaml
---
name: "dev-team"
created: "2026-03-03"
---
```

Followed by a members table:

```markdown
| Handle | Name | Role | Capacity (h/day) |
|--------|------|------|-------------------|
| @alice | Alice | Developer | 8 |
```

### Related Files

| File | Purpose |
|------|---------|
| `ceremonies.md` | Scrum ceremony schedule |
| `velocity.md` | Velocity history table |

---

## Project Structure

```
projects/{name}/
├── backlog/
│   ├── pbi-001.md
│   ├── pbi-002.md
│   └── archive/          ← Completed PBIs
├── sprints/
│   ├── current.md         ← Active sprint pointer
│   └── sprint-YYYY-NN/
│       └── sprint.md
├── specs/
├── decisions/
└── metrics/
```
