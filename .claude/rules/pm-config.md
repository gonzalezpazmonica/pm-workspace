# Regla: Configuración PM-Workspace
# ── Constantes de configuración Azure DevOps y proyectos ─────────────────────

> Esta regla se carga bajo demanda. Contiene los valores de configuración completos.

```
# ── Azure DevOps ──────────────────────────────────────────────────────────────
AZURE_DEVOPS_ORG_URL        = "https://dev.azure.com/MI-ORGANIZACION"
AZURE_DEVOPS_ORG_NAME       = "MI-ORGANIZACION"
AZURE_DEVOPS_PAT_FILE       = "$HOME/.azure/devops-pat"          # fichero con el PAT (sin comillas, sin salto de línea)
AZURE_DEVOPS_API_VERSION    = "7.1"

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

**Scopes PAT requeridos:** Work Items R/W · Project and Team R · Analytics R · Code R · Build R
