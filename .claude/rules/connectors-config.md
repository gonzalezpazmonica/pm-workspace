# Regla: Configuración de Conectores Claude

> Constantes y configuración para los conectores externos integrados en PM-Workspace.
> Los conectores se activan desde claude.ai/settings/connectors y se usan via MCP.

```
# ── Slack ────────────────────────────────────────────────────────────────────
SLACK_CONNECTOR_ENABLED     = true                               # Activar desde claude.ai/settings/connectors
SLACK_DEFAULT_CHANNEL       = ""                                 # Canal por defecto para notificaciones (#pm-updates)
SLACK_THREAD_REPLIES        = true                               # Responder en hilo cuando se notifica en canal existente

# ── GitHub ───────────────────────────────────────────────────────────────────
GITHUB_CONNECTOR_ENABLED    = true
GITHUB_DEFAULT_ORG          = ""                                 # Organización GitHub por defecto

# ── Sentry ───────────────────────────────────────────────────────────────────
SENTRY_CONNECTOR_ENABLED    = false
SENTRY_DEFAULT_ORG          = ""                                 # Organización Sentry

# ── Atlassian (Jira + Confluence) ────────────────────────────────────────────
ATLASSIAN_CONNECTOR_ENABLED = false
JIRA_DEFAULT_PROJECT        = ""                                 # Clave de proyecto Jira (ej: PROJ)
CONFLUENCE_DEFAULT_SPACE    = ""                                 # Espacio Confluence para publicar

# ── Google Drive ─────────────────────────────────────────────────────────────
GDRIVE_CONNECTOR_ENABLED    = false
GDRIVE_REPORTS_FOLDER       = ""                                 # ID de carpeta para informes

# ── Notion ───────────────────────────────────────────────────────────────────
NOTION_CONNECTOR_ENABLED    = false
NOTION_DEFAULT_DATABASE     = ""                                 # ID de base de datos principal

# ── Linear ───────────────────────────────────────────────────────────────────
LINEAR_CONNECTOR_ENABLED    = false
LINEAR_DEFAULT_TEAM         = ""                                 # Equipo Linear por defecto

# ── Figma ────────────────────────────────────────────────────────────────────
FIGMA_CONNECTOR_ENABLED     = false
FIGMA_DEFAULT_PROJECT       = ""                                 # Proyecto Figma por defecto
```

## Configuración por proyecto

Cada proyecto puede sobrescribir estos valores en `projects/{proyecto}/CLAUDE.md`:

```markdown
## Conectores
SLACK_CHANNEL       = "#proyecto-alpha-dev"
SENTRY_PROJECT      = "proyecto-alpha-api"
GITHUB_REPO         = "org/proyecto-alpha"
JIRA_PROJECT        = "ALPHA"
```

## Prerequisitos

Los conectores de Claude requieren:
1. Plan Pro, Max, Team o Enterprise en claude.ai
2. Activar el conector en claude.ai/settings/connectors
3. Autorizar el acceso OAuth cuando se solicite
4. Configurar los valores del proyecto en su CLAUDE.md

Si un conector no está activado y un comando intenta usarlo, mostrar:
```
⚠️ El conector {nombre} no está activado.
Actívalo en: claude.ai/settings/connectors
```
