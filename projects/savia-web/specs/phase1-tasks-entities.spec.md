# Spec: Tasks as First-Class Entities

## Metadatos
- project: savia-web
- phase: 1 — Backlog Data Model
- feature: tasks-entities
- status: pending
- developer_type: agent
- depends: phase1-pbi-history (shares `## Historial` pattern)

## Objective

Promote tasks from inline table rows inside PBIs to independent markdown files with full frontmatter, time tracking, and change history. This is the foundation for assignment, estimation, and reporting — equivalent to Azure DevOps Task work items.

## Data Model

### Directory structure

```
projects/{project}/backlog/
├── pbi/
│   └── PBI-004-test-item.md
├── tasks/                          ← NEW
│   ├── TASK-004-001-implement-endpoint.md
│   ├── TASK-004-002-write-tests.md
│   └── TASK-004-003-document-api.md
└── _config.yaml                    ← UPDATED
```

Naming convention: `TASK-{PBI_NUMBER}-{SEQ}-{slug}.md`

### Task frontmatter

```yaml
---
id: TASK-004-001
title: "Implementar endpoint GET /api/salas"
parent_pbi: PBI-004
spec: ""                          # path to spec file if exists
type: Development                 # Development | Testing | Documentation | Design | DevOps
state: New                        # New | Active | In Review | Done | Blocked
assigned_to: ""                   # @handle or empty
estimated_hours: 0
remaining_hours: 0
sprint: ""
tags: []
created: 2026-03-14
updated: 2026-03-14
---
```

### Task body sections

```markdown
## Descripcion
What this task involves.

## Registro de Horas
| Fecha | Autor | Horas | Tipo | Nota |
|-------|-------|-------|------|------|

## Historial
| Fecha | Autor | Campo | Anterior | Nuevo |
|-------|-------|-------|----------|-------|
| 2026-03-14 10:00 | @monica | _created | | TASK-004-001 |
```

### Registro de Horas fields

| Column | Type | Description |
|--------|------|-------------|
| Fecha | YYYY-MM-DD | Date of work |
| Autor | @handle | Who did the work |
| Horas | decimal | Hours worked (e.g., 1.5) |
| Tipo | enum | `dev` `review` `test` `doc` `meeting` `fix` `deploy` |
| Nota | string | Brief description of what was done |

### Updated PBI Tasks section

The `## Tasks` section in PBI files changes from flat table to linked references:

```markdown
## Tasks
| Task | Titulo | Estado | Asignado | Est. | Imputado |
|------|--------|--------|----------|------|----------|
| [TASK-004-001](../tasks/TASK-004-001-implement-endpoint.md) | Implementar endpoint | Active | @alice | 4h | 3.5h |
| [TASK-004-002](../tasks/TASK-004-002-write-tests.md) | Tests unitarios | New | | 2h | 0h |
```

The `Est.` and `Imputado` columns are computed from the task file's `estimated_hours` and sum of `## Registro de Horas`.

### Updated _config.yaml

```yaml
# Backlog configuration
project: "savia-web"
created: "2026-03-14"
pbi:
  states: [New, Active, Resolved, Closed]
  types: [User Story, Bug, Tech Debt, Spike]
  priorities: [1-Critical, 2-High, 3-Medium, 4-Low]
  id_prefix: "PBI"
  id_counter: 19
tasks:
  states: [New, Active, In Review, Done, Blocked]
  types: [Development, Testing, Documentation, Design, DevOps]
  id_prefix: "TASK"
sync:
  provider: ""
  auto_sync: false
  last_sync: ""
```

## Implementation

### 1. Commands

**`/task-create {pbi-id} [--title "..."] [--type Development]`**
- Creates `backlog/tasks/TASK-{PBI}-{seq}-{slug}.md` with frontmatter
- Appends link row to parent PBI's `## Tasks` section
- Logs `_created` in task's `## Historial`
- Auto-increments seq by reading existing tasks for that PBI

**`/task-log {task-id} {hours} [--type dev] [--note "..."]`**
- Appends row to `## Registro de Horas`
- Updates `remaining_hours` = max(0, remaining - hours)
- Updates `updated` date
- Logs `remaining_hours` change in `## Historial`

**`/task-history {task-id}`**
- Same behavior as `/pbi-history` but for task files

**`/pbi-tasks {pbi-id}`**
- Lists all tasks for a PBI with summary: state, @assigned, estimated, logged
- Shows totals: total estimated, total logged, remaining

### 2. Hook: `task-history-capture.sh` (PostToolUse, matcher: Edit|Write)

Same pattern as `pbi-history-capture.sh` but for `backlog/tasks/TASK-*.md` files.

### 3. Bridge API endpoints

```
GET  /backlog/tasks?pbi={pbi-id}           → TaskSummary[]
GET  /backlog/tasks/{task-id}              → TaskDetail (full)
POST /backlog/tasks                        → Create task
PATCH /backlog/tasks/{task-id}             → Update fields
POST /backlog/tasks/{task-id}/log          → Log hours
GET  /backlog/tasks/{task-id}/history      → HistoryEntry[]
GET  /backlog/tasks/{task-id}/hours        → TimeEntry[]
```

## Migration

Existing PBIs with inline task rows: parse the current `## Tasks` table and create individual task files. Mark migrated tasks with `_migrated` in their `## Historial`.

## Acceptance Criteria

- [ ] AC-1: `/task-create PBI-004 --title "Implement API" --type Development` creates `backlog/tasks/TASK-004-001-implement-api.md`
- [ ] AC-2: Created task has full frontmatter with `parent_pbi: PBI-004`
- [ ] AC-3: Parent PBI's `## Tasks` section gets a new linked row
- [ ] AC-4: `/task-log TASK-004-001 2.0 --type dev --note "Endpoint base"` appends to `## Registro de Horas`
- [ ] AC-5: Logging hours updates `remaining_hours` and logs change in `## Historial`
- [ ] AC-6: `/pbi-tasks PBI-004` shows all tasks with totals
- [ ] AC-7: Editing a task's `state` or `assigned_to` triggers history capture with @author
- [ ] AC-8: Bridge endpoints return correct JSON for all CRUD operations
- [ ] AC-9: `_config.yaml` has `tasks:` section with states and types
- [ ] AC-10: Existing inline task rows are migrated to individual files
