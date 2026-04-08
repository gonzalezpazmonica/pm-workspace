# Regla: Configuración PM-Workspace
# ── Constantes de configuración Azure DevOps y proyectos ─────────────────────

> Esta regla se carga bajo demanda. Contiene los valores de configuración completos.

```
# ── Azure DevOps ──────────────────────────────────────────────────────────────
AZURE_DEVOPS_ORG_URL        = "https://dev.azure.com/MI-ORGANIZACION"
AZURE_DEVOPS_ORG_NAME       = "MI-ORGANIZACION"
AZURE_DEVOPS_PAT_FILE       = "$HOME/.azure/devops-pat"          # fichero con el PAT (sin comillas, sin salto de línea)
AZURE_DEVOPS_API_VERSION    = "7.1"

# ── PM (Project Manager) ─────────────────────────────────────────────────────
AZURE_DEVOPS_PM_USER        = "nombre.apellido@miorganizacion.com"  # email o uniqueName del PM en Azure DevOps
AZURE_DEVOPS_PM_DISPLAY     = "Nombre Apellido"                     # nombre para mostrar en informes

# ── Proyectos activos ─────────────────────────────────────────────────────────
# Los proyectos reales (privados) están en pm-config.local.md (git-ignorado).
# Formato para añadir un proyecto Azure DevOps en pm-config.local.md:
#   PROJECT_XXX_NAME           = "NombreExactoEnAzureDevOps"
#   PROJECT_XXX_TEAM           = "NombreEquipo Team"
#   PROJECT_XXX_ITERATION_PATH = "NombreExactoEnAzureDevOps\\Sprints"

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
PM_WORKSPACE_ROOT           = "$(pwd)"
PROJECTS_DIR                = "./projects"
DOCS_DIR                    = "./docs"
SKILLS_DIR                  = "./.claude/skills"
OUTPUT_DIR                  = "./output"
SCRIPTS_DIR                 = "./scripts"

# ── Reporting ─────────────────────────────────────────────────────────────────
REPORT_LANGUAGE             = "es"
REPORT_CORPORATE_LOGO       = "./assets/logo.png"
VELOCITY_AVERAGE_SPRINTS    = 5                                   # nº sprints para media de velocity
WIP_LIMIT_PER_PERSON        = 2
WIP_LIMIT_PER_COLUMN        = 5

# ── Spec-Driven Development (SDD) ─────────────────────────────────────────────
CLAUDE_MODEL_AGENT          = "claude-opus-4-6"                   # modelo para agentes de implementación
CLAUDE_MODEL_MID            = "claude-sonnet-4-6"                 # modelo para tareas medianas/balanceadas
CLAUDE_MODEL_FAST           = "claude-haiku-4-5-20251001"         # modelo para agentes de tests/scaffolding
AGENT_LOGS_DIR              = "./output/agent-runs"
SPECS_BASE_DIR              = "./projects"
SPEC_EXTENSION              = ".spec.md"
SDD_MAX_PARALLEL_AGENTS     = 5
SDD_DEFAULT_MAX_TURNS       = 40

# ── Testing y Calidad ───────────────────────────────────────────────────────
TEST_COVERAGE_MIN_PERCENT   = 80                                    # % mínimo de cobertura exigido por test-runner
TOOL_RESULT_MAX_CHARS       = 5000                                   # hard cap per tool result

# ── Modos Autónomos ─────────────────────────────────────────────────────────
# Regla completa: @.claude/rules/domain/autonomous-safety.md
AUTONOMOUS_REVIEWER         = ""                                     # handle del humano que revisa PRs autónomos (OBLIGATORIO para arrancar)
AUTONOMOUS_RESEARCH_NOTIFY  = ""                                     # handle del humano que recibe informes de investigación
OVERNIGHT_SPRINT_ENABLED    = false                                  # activar/desactivar modo nocturno
OVERNIGHT_MAX_TASKS         = 20                                     # máximo de tareas por sesión nocturna
AGENT_TASK_TIMEOUT_MINUTES  = 15                                     # time-box por tarea de agente autónomo
AGENT_MAX_CONSECUTIVE_FAILURES = 3                                   # fallos consecutivos antes de escalar modelo o abortar

# ── Onboarding ──────────────────────────────────────────────────────────────
ONBOARDING_AUTO_DOCS_COUNT  = 12                                     # documentos base a auto-generar en onboarding
ONBOARDING_BUDDY_AGENT      = "buddy-ia"                             # agente buddy para onboarding técnico

# ── Legal Compliance (legalize-es) ─────────────────────────────────────────
LEGALIZE_ES_PATH            = "$HOME/.savia/legalize-es"              # ruta del corpus legislativo
LEGALIZE_ES_AUTO_UPDATE     = true                                    # git pull automático al inicio
LEGALIZE_ES_DEFAULT_CCAA    = ""                                      # CCAA por defecto (vacío = solo estatal)
```

## 🔐 Autenticación

```bash
# PAT Azure DevOps: $HOME/.azure/devops-pat (una sola línea, sin salto)
az devops configure --defaults organization=$AZURE_DEVOPS_ORG_URL
export AZURE_DEVOPS_EXT_PAT=$(cat $HOME/.azure/devops-pat)

# Graph API token:
curl -X POST "https://login.microsoftonline.com/$GRAPH_TENANT_ID/oauth2/v2.0/token" \
  -d "client_id=$GRAPH_CLIENT_ID&client_secret=$(cat $HOME/.azure/graph-secret)&scope=https://graph.microsoft.com/.default&grant_type=client_credentials"
```

**Scopes PAT requeridos:** Work Items R/W · Project and Team R · Analytics R · Code R/W · Build R/W · Release R

```
# ── Diagram Tools (Draw.io / Miro) ──────────────────────────────────────────
DRAWIO_MCP_URL              = "https://mcp.draw.io/mcp"           # MCP HTTP oficial, sin auth
MIRO_MCP_URL                = "https://mcp.miro.com"              # MCP HTTP oficial, OAuth 2.1
MIRO_TOKEN_FILE             = "$HOME/.azure/miro-token"            # fichero con OAuth token (sin salto de línea)

# ── Per-Project Diagram Settings (en pm-config.local.md) ────────────────────
# Formato:
#   PROJECT_XXX_DRAWIO_FOLDER   = "Folder/Path"                   # carpeta en Draw.io
#   PROJECT_XXX_MIRO_BOARD_ID   = "uXjVN..."                      # ID del board en Miro
#   PROJECT_XXX_DIAGRAM_TOOL    = "draw-io"                        # tool preferido (draw-io|miro)

# ── Azure Repos (Git provider por proyecto) ───────────────────────────────
# Formato en pm-config.local.md:
#   PROJECT_XXX_GIT_PROVIDER        = "github"                       # github | azure-repos
#   PROJECT_XXX_AZURE_REPOS_REPO    = "backend-api"                  # repo por defecto en Azure Repos
#   PROJECT_XXX_AZURE_REPOS_BRANCH  = "main"                         # rama principal
```
