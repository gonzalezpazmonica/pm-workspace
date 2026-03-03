# Regla: Configuración Savia Flow — Git-Native Task Management
# ── Tasks, Sprints, Timesheets, especificaciones — todo en Git ────────────────

> Esta regla se carga bajo demanda con comandos `/flow-*`.
> Savia Flow no usa bases de datos — solo Git y ficheros de texto.

```
# ── Estructura de Datos ────────────────────────────────────────────────────────
FLOW_DATA_DIR               = "./.savia-flow-data"
FLOW_REPO_INITIALIZED       = false

# ── Directorios Principales ───────────────────────────────────────────────────
BACKLOG_DIR                 = "${FLOW_DATA_DIR}/backlog"
SPRINTS_DIR                 = "${FLOW_DATA_DIR}/sprints"
SPECS_DIR                   = "${FLOW_DATA_DIR}/specs"
TIMESHEETS_DIR              = "${FLOW_DATA_DIR}/timesheets"
REPORTS_DIR                 = "${FLOW_DATA_DIR}/reports"
TEAM_DIR                    = "${FLOW_DATA_DIR}/team"
INDEX_DIR                   = "${FLOW_DATA_DIR}/.savia-index"

# ── ID Generation ──────────────────────────────────────────────────────────────
TASK_ID_FORMAT              = "TASK-YYYY-NNNN"         # TASK-2026-0042
SPRINT_ID_FORMAT            = "SPR-YYYY-NN"            # SPR-2026-02
SPEC_ID_FORMAT              = "SPEC-YYYY-NNN"          # SPEC-2026-001

# ── Sprint Configuration ───────────────────────────────────────────────────────
SPRINT_DURATION_WEEKS       = 2
SPRINT_START_DAY            = "Monday"
SPRINT_CAPACITY_DEFAULT_H   = 120

# ── Task States ────────────────────────────────────────────────────────────────
TASK_STATES                 = ["todo", "in-progress", "review", "done"]
TASK_BLOCKED_STATE          = "blocked"
TASK_TYPES                  = ["task", "bug", "spike", "subtask", "feature"]
TASK_PRIORITIES             = ["critical", "high", "medium", "low"]

# ── Board Column Structure ─────────────────────────────────────────────────────
BOARD_COLUMNS               = ["todo", "in-progress", "review", "done"]
BOARD_WIP_LIMITS            = {
  "in-progress": 3,
  "review": 2,
  "done": "unlimited"
}

# ── Task Metadata (Frontmatter) ────────────────────────────────────────────────
TASK_FIELDS                 = {
  "id": "TASK-YYYY-NNNN",
  "type": "task|bug|spike|subtask",
  "parent": "FEAT-YYYY-NNN",
  "title": "string",
  "assigned": "@handle",
  "status": "todo|in-progress|review|done|blocked",
  "priority": "critical|high|medium|low",
  "estimate_h": "number",
  "spent_h": "number",
  "sprint": "SPR-YYYY-NN",
  "tags": ["tag1", "tag2"],
  "created": "YYYY-MM-DD",
  "updated": "YYYY-MM-DD"
}

# ── Sprint Metadata ────────────────────────────────────────────────────────────
SPRINT_FIELDS               = {
  "id": "SPR-YYYY-NN",
  "goal": "string",
  "start_date": "YYYY-MM-DD",
  "end_date": "YYYY-MM-DD",
  "capacity_h": "number",
  "status": "active|closed|planning",
  "created": "YYYY-MM-DD",
  "closed": "YYYY-MM-DD",
  "velocity": "number"
}

# ── Timesheet Format ───────────────────────────────────────────────────────────
TIMESHEET_DIR_STRUCTURE     = "timesheets/{handle}/{YYYY-MM}/entries.log"
TIMESHEET_FORMAT            = "YYYY-MM-DD HH:MM | task_id | hours | notes"

# ── Index Files for Fast Lookups ──────────────────────────────────────────────
INDEX_TASKS                 = "${INDEX_DIR}/tasks.idx"
INDEX_SPRINTS               = "${INDEX_DIR}/sprints.idx"
INDEX_SPECS                 = "${INDEX_DIR}/specs.idx"
INDEX_TIMESHEETS            = "${INDEX_DIR}/timesheets.idx"

# ── Git Configuration ──────────────────────────────────────────────────────────
GIT_COMMIT_PREFIX           = "flow:"
GIT_BRANCH_PREFIX           = "flow/"
FLOW_COMMIT_FORMAT          = "[flow: {action}] {entity}: {description}"

# ── Velocity Calculation ───────────────────────────────────────────────────────
VELOCITY_WINDOW_SPRINTS     = 5
VELOCITY_CALCULATION        = "completed_tasks_in_done_column"

# ── Default Team Capacity ──────────────────────────────────────────────────────
TEAM_HOURS_PER_DAY          = 8
TEAM_FOCUS_FACTOR           = 0.75
TEAM_DEFAULT_CAPACITY       = 120                      # 2 weeks * 5 days * 8h * 0.75

# ── Burndown Configuration ─────────────────────────────────────────────────────
BURNDOWN_TRACKING           = "daily_snapshot"         # or time-series if available
BURNDOWN_COLUMNS            = ["todo", "in-progress", "review", "done"]

# ── Privacy & Security ─────────────────────────────────────────────────────────
FLOW_ENCRYPT_SENSITIVE      = false                    # Tasks no son sensibles
FLOW_GIT_IGNORE             = []                       # TODO: add secrets if any
```

## Directorio Completo

```
.savia-flow-data/
├── .flow-config.md
├── .savia-index/
│   ├── tasks.idx
│   ├── sprints.idx
│   ├── specs.idx
│   └── timesheets.idx
├── backlog/
│   ├── TASK-2026-0001.md (features/)
│   ├── TASK-2026-0002.md (bugs/)
│   └── TASK-2026-0003.md (tech-debt/)
├── sprints/
│   ├── SPR-2026-01/
│   │   ├── sprint.md
│   │   ├── board/
│   │   │   ├── todo/
│   │   │   ├── in-progress/
│   │   │   ├── review/
│   │   │   └── done/
│   │   └── daily/
│   │       ├── 2026-03-03.md
│   │       └── 2026-03-04.md
│   └── SPR-2026-02/
├── specs/
│   ├── SPEC-2026-001/
│   │   ├── spec.md
│   │   └── design.md
│   └── SPEC-2026-002/
├── timesheets/
│   ├── @developer-1/
│   │   ├── 2026-02/entries.log
│   │   └── 2026-03/entries.log
│   └── @developer-2/
├── team/
│   ├── @developer-1.md (capacity, skills)
│   └── @developer-2.md
└── reports/
    ├── SPR-2026-01-summary.md
    └── velocity-trend.md
```

## Comandos Relacionados

| Comando | Función |
|---------|---------|
| `/flow-task-create` | Create task |
| `/flow-task-move` | Move task between columns |
| `/flow-task-assign` | Assign task |
| `/flow-sprint-create` | Create sprint |
| `/flow-sprint-close` | Close and report |
| `/flow-sprint-board` | View board |
| `/flow-timesheet` | Log hours |
| `/flow-timesheet-report` | Generate report |
| `/flow-burndown` | Show burndown |
| `/flow-velocity` | Historical velocity |
| `/flow-spec-create` | Create SDD spec |
| `/flow-backlog-groom` | Prioritize backlog |

## Scripts Subyacentes

- `scripts/savia-flow-tasks.sh` — CRUD de tasks
- `scripts/savia-flow-sprint.sh` — Sprint lifecycle
- `scripts/savia-flow-timesheet.sh` — Time tracking

## Validación Pre-Uso

- [ ] `.savia-flow-data/` creado
- [ ] `.flow-config.md` con valores
- [ ] `.savia-index/` directorio existe
- [ ] Todos los scripts ejecutables (chmod +x)
