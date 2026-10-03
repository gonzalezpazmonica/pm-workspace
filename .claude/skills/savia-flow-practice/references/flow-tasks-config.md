# Regla: Configuración Savia Flow — Git-Native Task Management

> Se carga bajo demanda con comandos `/flow-*`. Savia Flow no usa BBDD — solo Git y ficheros de texto.

```
# ── Estructura ────────────────────────────────────────────────────────────────
FLOW_DATA_DIR               = "./.savia-flow-data"
BACKLOG_DIR                 = "${FLOW_DATA_DIR}/backlog"
SPRINTS_DIR                 = "${FLOW_DATA_DIR}/sprints"
SPECS_DIR                   = "${FLOW_DATA_DIR}/specs"
TIMESHEETS_DIR              = "${FLOW_DATA_DIR}/timesheets"
REPORTS_DIR                 = "${FLOW_DATA_DIR}/reports"
TEAM_DIR                    = "${FLOW_DATA_DIR}/team"
INDEX_DIR                   = "${FLOW_DATA_DIR}/.savia-index"

# ── IDs ───────────────────────────────────────────────────────────────────────
TASK_ID_FORMAT              = "TASK-NNNN"        # secuencial por proyecto (max + 1)
SPRINT_ID_FORMAT            = "SPR-YYYY-NN"      # YYYY = anio de start_date
SPEC_ID_FORMAT              = "SPEC-YYYY-NNN"

# ── Sprint ────────────────────────────────────────────────────────────────────
SPRINT_DURATION_WEEKS       = 2
SPRINT_START_DAY            = "Monday"
SPRINT_CAPACITY_DEFAULT_H   = 120

# ── Task States & Board ──────────────────────────────────────────────────────
TASK_STATES                 = ["todo", "in-progress", "review", "done"]
TASK_TYPES                  = ["task", "bug", "spike", "subtask"]
TASK_PRIORITIES             = ["critical", "high", "medium", "low"]
BOARD_WIP_LIMITS            = { "in-progress": 3, "review": 2 }

# ── Task Frontmatter ─────────────────────────────────────────────────────────
TASK_FIELDS = {
  "id", "type", "parent", "title", "assigned", "status",
  "priority", "estimate_h", "spent_h", "sprint", "tags",
  "created", "updated"
}

# ── Sprint Frontmatter ───────────────────────────────────────────────────────
SPRINT_FIELDS = {
  "id", "goal", "start_date", "end_date", "capacity_h",
  "status": "active|closed|planning", "velocity"
}

# ── Timesheet & Git ──────────────────────────────────────────────────────────
TIMESHEET_FORMAT            = "YYYY-MM-DD HH:MM | task_id | {horas}h | notes"
TIMESHEET_MAX_HOURS_ENTRY   = 24                 # > 0, max 2 decimales, coma o punto
TIMESHEET_DIR_STRUCTURE     = "rama user/{handle}: flow/timesheet/{YYYY-MM}.md"
GIT_COMMIT_PREFIX           = "flow:"
FLOW_COMMIT_FORMAT          = "[flow: {action}] {entity}: {description}"

# ── Velocity & Capacity ──────────────────────────────────────────────────────
VELOCITY_WINDOW_SPRINTS     = 5
TEAM_HOURS_PER_DAY          = 8
TEAM_FOCUS_FACTOR           = 0.75
TEAM_DEFAULT_CAPACITY       = 120
```

## Directorio (implementado)

Los scripts no usan `.savia-flow-data/`: escriben en el repo de empresa
(`LOCAL_PATH` de `~/.pm-workspace/company-repo`) con aislamiento por ramas.

```
rama team/{team}
├── projects/{proyecto-de-equipo}/sprints/SPR-YYYY-NN/sprint.md   # savia-flow-sprint.sh
└── projects/{proyecto}/backlog/pbi-NNNN.md                       # savia-flow-tasks.sh (proyecto "default")
rama user/{handle}
└── flow/timesheet/YYYY-MM.md                                     # savia-flow-timesheet.sh
```

Las escrituras pasan por un lock por rama (`do_with_lock` en `savia-branch.sh`):
imputaciones o altas concurrentes no se pisan.

## Comandos

| Comando | Función |
|---------|---------|
| `/flow-task-create` | Create task |
| `/flow-task-move` | Move between columns |
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

## Scripts

- `scripts/savia-flow-tasks.sh` — CRUD de tasks
- `scripts/savia-flow-sprint.sh` — Sprint lifecycle
- `scripts/savia-flow-timesheet.sh` — Time tracking

## Pre-Uso: repo de empresa conectado (`/company-repo connect`) con `LOCAL_PATH` y `TEAM_NAME`
