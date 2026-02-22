# PM Workspace — Contexto Global para Claude Code

> Este fichero es el punto de entrada de Claude Code. Léelo completo antes de cualquier acción.

---

## ⚙️ CONSTANTES DE CONFIGURACIÓN

Edita esta sección antes de empezar. Son los valores que se usan en todos los scripts y skills.

```
# ── Azure DevOps ──────────────────────────────────────────────────────────────
AZURE_DEVOPS_ORG_URL        = "https://dev.azure.com/MI-ORGANIZACION"
AZURE_DEVOPS_ORG_NAME       = "MI-ORGANIZACION"
AZURE_DEVOPS_PAT_FILE       = "$HOME/.azure/devops-pat"          # fichero con el PAT (sin comillas, sin salto de línea)
AZURE_DEVOPS_API_VERSION    = "7.1"

# ── Proyectos activos (nombre exacto en Azure DevOps) ────────────────────────
PROJECT_ALPHA_NAME          = "ProyectoAlpha"
PROJECT_ALPHA_TEAM          = "ProyectoAlpha Team"
PROJECT_ALPHA_ITERATION_PATH = "ProyectoAlpha\\Sprints"

PROJECT_BETA_NAME           = "ProyectoBeta"
PROJECT_BETA_TEAM           = "ProyectoBeta Team"
PROJECT_BETA_ITERATION_PATH = "ProyectoBeta\\Sprints"

# ── Configuración de sprints ──────────────────────────────────────────────────
SPRINT_DURATION_WEEKS       = 2                                   # duración estándar de sprint
SPRINT_START_DAY            = "Monday"                            # día de inicio de sprint
SPRINT_START_HOUR           = "09:00"
DAILY_STANDUP_TIME          = "09:15"
SPRINT_REVIEW_DURATION_MIN  = 60
SPRINT_RETRO_DURATION_MIN   = 90

# ── Capacidad del equipo ──────────────────────────────────────────────────────
TEAM_HOURS_PER_DAY          = 8
TEAM_FOCUS_FACTOR           = 0.75                                # factor de foco (75 % horas productivas)
TEAM_CAPACITY_FORMULA       = "dias_habiles * horas_dia * focus_factor"

# ── Microsoft Graph API (Office 365) ─────────────────────────────────────────
GRAPH_TENANT_ID             = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
GRAPH_CLIENT_ID             = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
GRAPH_CLIENT_SECRET_FILE    = "$HOME/.azure/graph-secret"
SHAREPOINT_SITE_URL         = "https://MI-ORGANIZACION.sharepoint.com/sites/PMReports"
SHAREPOINT_REPORTS_PATH     = "Documentos compartidos/Informes PM"
ONEDRIVE_REPORTS_FOLDER     = "Informes"

# ── Rutas locales ─────────────────────────────────────────────────────────────
PM_WORKSPACE_ROOT           = "$(pwd)"                            # raíz de este repositorio
PROJECTS_DIR                = "./projects"
DOCS_DIR                    = "./docs"
SKILLS_DIR                  = "./.claude/skills"
OUTPUT_DIR                  = "./output"
SCRIPTS_DIR                 = "./scripts"

# ── Reporting ─────────────────────────────────────────────────────────────────
REPORT_LANGUAGE             = "es"                                # idioma de los informes
REPORT_CORPORATE_LOGO       = "./assets/logo.png"                 # logo para informes (añadir si existe)
VELOCITY_AVERAGE_SPRINTS    = 5                                   # nº sprints para media de velocity
WIP_LIMIT_PER_PERSON        = 2                                   # WIP máximo por persona
WIP_LIMIT_PER_COLUMN        = 5                                   # WIP máximo por columna del board

# ── Spec-Driven Development (SDD) ─────────────────────────────
CLAUDE_MODEL_AGENT          = "claude-opus-4-5-20251101"          # modelo para agentes de implementación
CLAUDE_MODEL_FAST           = "claude-haiku-4-5-20251001"         # modelo para agentes de tests/scaffolding
AGENT_LOGS_DIR              = "./output/agent-runs"               # directorio de logs de agentes
SPECS_BASE_DIR              = "./projects"                        # las specs se guardan en projects/{proyecto}/specs/
SPEC_EXTENSION              = ".spec.md"                          # extensión de ficheros de spec
SDD_MAX_PARALLEL_AGENTS     = 5                                   # máximo agentes en paralelo por sesión
SDD_DEFAULT_MAX_TURNS       = 40                                  # turns máximos por agente
```

---

## 🎯 Mi Rol

Soy **Project Manager / Scrum Master** que gestiona proyectos .NET con equipos Scrum. Utilizo Azure DevOps para:
- Gestionar sprints (planning, daily tracking, review, retrospectiva)
- Controlar capacidades y asignaciones del equipo
- Generar informes de imputación de horas
- Producir informes ejecutivos para dirección

---

## 📁 Estructura del Workspace

```
pm-workspace/
├── CLAUDE.md                   ← ESTE FICHERO (léelo siempre primero)
├── .claude/
│   ├── settings.local.json     ← Permisos Claude Code
│   ├── .env                    ← Variables de entorno (NO commitear)
│   ├── mcp.json                ← Configuración MCP opcional
│   ├── commands/               ← Slash commands (/sprint:status, etc.)
│   └── skills/                 ← Skills personalizadas
│       ├── azure-devops-queries/
│       ├── sprint-management/
│       ├── capacity-planning/
│       ├── time-tracking-report/
│       ├── executive-reporting/
│       ├── pbi-decomposition/       ← Descomposición, estimación y asignación de PBIs
│       └── spec-driven-development/ ← SDD: specs como contrato para humanos y agentes Claude
│           └── references/
│               ├── spec-template.md
│               ├── layer-assignment-matrix.md
│               └── agent-team-patterns.md
├── docs/                       ← Reglas, KPIs, plantillas
│   ├── reglas-scrum.md
│   ├── reglas-negocio.md
│   ├── politica-estimacion.md
│   ├── kpis-equipo.md
│   ├── plantillas-informes.md
│   └── flujo-trabajo.md        ← incluye sección 8: SDD workflow
├── projects/                   ← Un directorio por proyecto
│   ├── proyecto-alpha/
│   │   ├── CLAUDE.md           ← Contexto específico + config SDD (sdd_config)
│   │   ├── equipo.md           ← Composición del equipo + agentes Claude como developers
│   │   ├── reglas-negocio.md   ← Reglas de negocio del proyecto
│   │   ├── source/             ← Código fuente (repo git)
│   │   ├── sprints/            ← Historial de sprints
│   │   └── specs/              ← Specs SDD del proyecto
│   │       ├── sdd-metrics.md
│   │       ├── templates/
│   │       └── sprint-YYYY-MM/ ← Specs del sprint
│   └── proyecto-beta/
│       └── (misma estructura)
├── scripts/                    ← Scripts auxiliares
│   ├── azdevops-queries.sh
│   ├── report-generator.js
│   └── capacity-calculator.py
└── output/                     ← Informes y logs generados
    ├── sprints/
    ├── reports/
    ├── executive/
    └── agent-runs/             ← Logs de ejecuciones de agentes Claude
```

---

## 🔐 Credenciales y Autenticación

**PAT de Azure DevOps:**
```bash
# El PAT está en $HOME/.azure/devops-pat (una sola línea, sin salto)
# Para usarlo en az cli:
az devops configure --defaults organization=$AZURE_DEVOPS_ORG_URL
export AZURE_DEVOPS_EXT_PAT=$(cat $HOME/.azure/devops-pat)
```

**Scopes requeridos para el PAT:**
- Work Items: Read & Write
- Project and Team: Read
- Analytics: Read
- Code: Read (para vincular commits)
- Build: Read (para estado de pipelines)

**Microsoft Graph (Office 365):**
```bash
# El client secret está en $HOME/.azure/graph-secret
# Para obtener token:
curl -X POST "https://login.microsoftonline.com/$GRAPH_TENANT_ID/oauth2/v2.0/token" \
  -d "client_id=$GRAPH_CLIENT_ID&client_secret=$(cat $HOME/.azure/graph-secret)&scope=https://graph.microsoft.com/.default&grant_type=client_credentials"
```

---

## 📋 Proyectos Activos

| Proyecto | Azure DevOps Project | Equipo | Sprint actual |
|----------|----------------------|--------|---------------|
| Alpha | ProyectoAlpha | ProyectoAlpha Team | Ver `projects/proyecto-alpha/CLAUDE.md` |
| Beta | ProyectoBeta | ProyectoBeta Team | Ver `projects/proyecto-beta/CLAUDE.md` |

Para contexto completo de un proyecto, lee siempre su `CLAUDE.md` específico antes de actuar.

---

## 📅 Cadencia Scrum

| Ceremonia | Cuándo | Duración |
|-----------|--------|----------|
| Sprint Planning | Lunes inicio sprint, 10:00 | 4h max |
| Daily Standup | Cada día laborable, 09:15 | 15 min |
| Sprint Review | Viernes fin sprint, 15:00 | 1h |
| Retrospectiva | Viernes fin sprint, 16:30 | 1.5h |
| Refinement | Miércoles semana 1 del sprint, 11:00 | 2h |

---

## 🛠️ Herramientas Disponibles

1. **Azure CLI** (`az devops`, `az boards`, `az repos`, `az pipelines`) — vía principal
2. **REST API directa** (`curl`) — para endpoints sin soporte CLI
3. **Skills personalizadas** — ver `.claude/skills/`
4. **Scripts auxiliares** — ver `scripts/`
5. **Agentes Claude Code** — para implementar Tasks vía SDD (ver `.claude/skills/spec-driven-development/`)

**Para cualquier operación con Azure DevOps, lee primero:**
→ `.claude/skills/azure-devops-queries/SKILL.md`

**Para descomponer PBIs en tasks y asignarlas, lee:**
→ `.claude/skills/pbi-decomposition/SKILL.md`

**Para generar Specs y delegar implementación a agentes Claude:**
→ `.claude/skills/spec-driven-development/SKILL.md`

---

## 📏 Convenciones

- **Branches:** `feature/AB#XXXX-descripcion`, `bugfix/AB#XXXX-descripcion`
- **Commits:** `[AB#XXXX] Descripción corta en imperativo`
- **Nomenclatura sprints:** `Sprint YYYY-NN` (ej: `Sprint 2026-04`)
- **Nomenclatura informes:** `YYYYMMDD-tipo-proyecto.ext` (ej: `20260222-sprint-report-alpha.xlsx`)

---

## ⚠️ Reglas Críticas

1. **NUNCA hardcodear el PAT** — siempre leer de fichero con `$(cat $PAT_FILE)`
2. **SIEMPRE filtrar por IterationPath** en queries WIQL salvo petición explícita
3. **Confirmar antes de escribir** en Azure DevOps — preguntar si la operación modifica datos
4. **Leer el CLAUDE.md del proyecto** antes de actuar sobre él
5. **Guardar informes en `output/`** con la nomenclatura definida
6. **Si algo se repite 2+ veces**, documentarlo en la skill correspondiente
7. **Descomposición de PBIs**: SIEMPRE presentar la propuesta completa antes de crear tasks; NUNCA crear sin confirmación explícita del usuario
8. **Spec-Driven Development**: NUNCA lanzar un agente sin una Spec aprobada; SIEMPRE revisar la Spec antes de ejecutar `/agent:run`; El Code Review (E1) es SIEMPRE humano

---

## 🔗 Referencias Rápidas

- Reglas Scrum: `docs/reglas-scrum.md`
- KPIs y métricas: `docs/kpis-equipo.md`
- Plantillas de informes: `docs/plantillas-informes.md`
- Política de estimación: `docs/politica-estimacion.md`
- Queries WIQL: `.claude/skills/azure-devops-queries/references/wiql-patterns.md`
- Scoring de asignación: `.claude/skills/pbi-decomposition/references/assignment-scoring.md`
- SDD Spec Template: `.claude/skills/spec-driven-development/references/spec-template.md`
- SDD Layer Matrix: `.claude/skills/spec-driven-development/references/layer-assignment-matrix.md`
- SDD Agent Patterns: `.claude/skills/spec-driven-development/references/agent-team-patterns.md`
- Azure DevOps API v7.1: https://learn.microsoft.com/en-us/rest/api/azure/devops/

## 📟 Comandos Disponibles — Tabla Completa

| Comando | Descripción |
|---------|-------------|
| `/sprint:status` | Estado del sprint actual: progreso, burndown, alertas |
| `/sprint:plan` | Asistente de Sprint Planning: capacity + PBIs candidatos |
| `/sprint:review` | Resumen para Sprint Review: velocity, items completados |
| `/sprint:retro` | Plantilla de retrospectiva con datos del sprint |
| `/report:hours` | Informe de imputación de horas (Excel) |
| `/report:executive` | Informe ejecutivo multi-proyecto (PPT/Word) |
| `/report:capacity` | Estado de capacidades del equipo |
| `/team:workload` | Carga de trabajo por persona |
| `/board:flow` | Análisis del flujo: WIP, cuellos de botella, cycle time |
| `/kpi:dashboard` | Dashboard completo de KPIs del equipo |
| `/pbi:decompose {id}` | Descomponer un PBI en tasks con estimación y asignación |
| `/pbi:decompose-batch {ids}` | Descomponer varios PBIs optimizando la carga global |
| `/pbi:assign {pbi_id}` | (Re)asignar tasks existentes de un PBI |
| `/pbi:plan-sprint` | Planning completo: capacity + PBIs + descomposición + asignación |
| `/spec:generate {task_id}` | Generar Spec ejecutable desde una Task de Azure DevOps |
| `/spec:implement {spec_file}` | Implementar una Spec (lanza agente Claude o asigna humano) |
| `/spec:review {spec_file}` | Revisar calidad de Spec o validar implementación resultante |
| `/spec:status` | Dashboard de estado de todas las Specs del sprint |
| `/agent:run {spec_file}` | Lanzar agente Claude directamente sobre una Spec |
