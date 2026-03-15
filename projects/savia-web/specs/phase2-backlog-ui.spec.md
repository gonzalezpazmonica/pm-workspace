# Spec: Savia Web — Backlog Management (Tree + Kanban)

## Metadatos
- project: savia-web
- phase: 2 — Savia Web Core
- feature: backlog-ui
- status: pending
- developer_type: human
- depends: phase1-pbi-history, phase1-tasks-entities, phase1-pbi-spec-links
- parent_pbi: ""

## Objective

Replace the current placeholder Kanban page with a complete backlog management UI offering two views: hierarchical tree (like Azure DevOps) and functional Kanban. Designed for non-programmers — a PM, PO, or stakeholder should be able to manage the full backlog without touching the terminal.

## Architecture

### Route: `/backlog`

Two view modes toggled by tabs:
- **Tree View** (default) — hierarchical: Epic > Feature > PBI > Task
- **Kanban View** — columns by state, cards are PBIs with task counts

### Data source

All data comes from the markdown files in `backlog/pbi/` and `backlog/tasks/` via Bridge API:

```
GET /backlog/pbi              → PBISummary[] (frontmatter + task counts)
GET /backlog/pbi/{id}         → PBIDetail (full content + tasks + specs + history)
GET /backlog/tasks?pbi={id}   → TaskSummary[]
GET /backlog/tasks/{id}       → TaskDetail (full content + hours + history)
PATCH /backlog/pbi/{id}       → Update PBI fields (state, priority, assigned_to, sprint...)
PATCH /backlog/tasks/{id}     → Update Task fields
POST /backlog/pbi             → Create new PBI
POST /backlog/tasks           → Create new Task
```

Bridge reads/writes the markdown files on disk. The web never touches files directly.

## Functional Requirements

### FR-01: Tree View

Hierarchical list, collapsible at each level. Each row shows:

| Column | PBI | Task |
|--------|-----|------|
| ID | PBI-004 | TASK-004-001 |
| Title | Backlog funcional | Implementar endpoint |
| Type | User Story | Development |
| State | Active (color badge) | In Review (color badge) |
| Priority | 2-High (icon) | — |
| Assigned | @alice | @bob |
| SP | 5 | — |
| Est. hours | 12h | 4h |
| Logged hours | 7.5h | 3.5h |

Click on row → opens detail panel (right side or modal).

Drag-and-drop between hierarchy levels:
- Drag a Task to a different PBI → updates `parent_pbi`
- Drag a PBI to reorder priority → updates `priority`

Toolbar: filter by state, assigned, sprint, type. Search by title/ID.

### FR-02: Kanban View

Columns: one per state defined in `_config.yaml` (New | Active | Resolved | Closed).

Cards are PBIs showing: ID, title, priority badge, @assigned_to avatar, task progress bar (done/total), SP badge.

Drag card between columns → updates PBI `state` field → triggers history capture.

WIP limit indicator: if column exceeds configurable limit (default 5), column header turns amber.

Swimlanes (optional toggle): group rows by sprint or by assignee.

### FR-03: PBI Detail Panel

Opens on click from tree or kanban. Tabs:

**Tab "Detalle"**: editable form for all frontmatter fields. Title, type (dropdown), state (dropdown), priority (dropdown), @assigned_to (autocomplete from team), estimation_sp, estimation_hours, sprint (dropdown), tags (chips). Description (markdown editor). Acceptance criteria (checklist with checkboxes).

**Tab "Tasks"**: table of linked tasks with inline state toggle and hours summary. Button "Nueva Task" → creates task via `/task-create`. Click task → opens Task Detail.

**Tab "Specs"**: list of linked specs with status badges. Button "Vincular Spec" → file picker. Click spec → opens spec viewer (readonly markdown).

**Tab "Historial"**: timeline of changes from `## Historial` section. Each entry shows: date, @author avatar, field, old→new. Filterable by field or @author.

### FR-04: Task Detail Panel

Opens from PBI Tasks tab or from tree view. Sections:

**Header**: ID, title, state badge, @assigned_to.

**Form**: type, state, @assigned_to, estimated_hours, remaining_hours, sprint.

**Registro de Horas**: table of time entries. Button "Imputar horas" → inline form (hours, type dropdown, note). Totals row at bottom.

**Historial**: same timeline pattern as PBI.

### FR-05: Create PBI

Button "+ Nuevo PBI" in toolbar. Modal form with: title (required), type (dropdown), priority (dropdown). Creates file via `POST /backlog/pbi`. Auto-generates ID from `_config.yaml` counter.

### FR-06: Create Task

Button "+ Nueva Task" in PBI detail Tasks tab. Inline form: title, type, @assigned_to, estimated_hours. Creates file via `POST /backlog/tasks`. Auto-links to parent PBI.

### FR-07: Bulk Actions

Multi-select (checkboxes) in tree view. Actions: change state, assign @handle, move to sprint, change priority. All changes logged in each item's history.

## Non-Functional Requirements

- NFR-01: All `.vue` files <= 150 lines
- NFR-02: Responsive — tree view collapses to card list on mobile widths
- NFR-03: Kanban drag-drop works on touch devices
- NFR-04: @handle autocomplete loads from team members list
- NFR-05: All state changes optimistic (update UI immediately, sync in background)
- NFR-06: Offline indicator if Bridge disconnects during editing
- NFR-07: Lucide icons for all actions and status badges
- NFR-08: Accessible — keyboard navigation, ARIA labels, focus management

## Vue Components (estimated)

```
src/pages/BacklogPage.vue           ← route /backlog, view toggle
src/components/backlog/
  TreeView.vue                      ← hierarchical list
  TreeRow.vue                       ← single row (PBI or Task)
  KanbanBoard.vue                   ← columns layout
  KanbanCard.vue                    ← single PBI card
  PbiDetail.vue                     ← detail panel with tabs
  PbiForm.vue                       ← editable form fields
  TaskDetail.vue                    ← task detail with hours
  TaskForm.vue                      ← task inline form
  TimeLogForm.vue                   ← log hours inline
  HistoryTimeline.vue               ← timeline from Historial
  SpecList.vue                      ← linked specs list
  BulkActions.vue                   ← multi-select toolbar
  BacklogFilters.vue                ← filter bar
src/stores/backlog.ts               ← Pinia store for PBIs + Tasks
src/composables/useBacklog.ts       ← Bridge API calls
src/types/backlog.ts                ← TypeScript interfaces
```

## Acceptance Criteria

- [ ] AC-1: Tree view shows PBIs with nested Tasks, collapsible
- [ ] AC-2: Kanban view shows PBIs as cards in state columns
- [ ] AC-3: Dragging a card between kanban columns updates state and logs in Historial
- [ ] AC-4: PBI detail shows 4 tabs: Detalle, Tasks, Specs, Historial
- [ ] AC-5: Editing a PBI field saves via Bridge and appears in Historial
- [ ] AC-6: Creating a new PBI from the UI produces a valid markdown file
- [ ] AC-7: Creating a new Task from PBI detail links it correctly
- [ ] AC-8: Logging hours on a Task updates remaining and shows in Registro
- [ ] AC-9: Bulk state change on 3+ PBIs works and logs history for each
- [ ] AC-10: Filter by @assigned_to shows only matching items
- [ ] AC-11: Non-programmer can create PBI, add tasks, log hours without terminal
