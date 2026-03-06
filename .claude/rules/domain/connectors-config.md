# Regla: Configuración de Conectores Claude

> Constantes y configuración para los conectores externos integrados en PM-Workspace.
> Los conectores se activan desde claude.ai/settings/connectors y se usan via MCP.
> Los Connectors configurados en claude.ai se sincronizan automáticamente con Claude Code
> (variable `ENABLE_CLAUDEAI_MCP_SERVERS=true` por defecto). No requieren `claude mcp add`.

```
# ── Slack ────────────────────────────────────────────────────────────────────
SLACK_CONNECTOR_ENABLED     = true                               # Activar desde claude.ai/settings/connectors
SLACK_DEFAULT_CHANNEL       = ""                                 # Canal por defecto para notificaciones (#pm-updates)
SLACK_THREAD_REPLIES        = true                               # Responder en hilo cuando se notifica en canal existente

# ── GitHub ───────────────────────────────────────────────────────────────────
GITHUB_CONNECTOR_ENABLED    = true
GITHUB_DEFAULT_ORG          = ""                                 # Organización GitHub por defecto

# ── Sentry ───────────────────────────────────────────────────────────────────
SENTRY_CONNECTOR_ENABLED    = true
SENTRY_DEFAULT_ORG          = ""                                 # Organización Sentry

# ── Atlassian (Jira + Confluence) ────────────────────────────────────────────
ATLASSIAN_CONNECTOR_ENABLED = true
JIRA_DEFAULT_PROJECT        = ""                                 # Clave de proyecto Jira (ej: PROJ)
CONFLUENCE_DEFAULT_SPACE    = ""                                 # Espacio Confluence para publicar

# ── Google Drive ─────────────────────────────────────────────────────────────
GDRIVE_CONNECTOR_ENABLED    = true
GDRIVE_REPORTS_FOLDER       = ""                                 # ID de carpeta para informes

# ── Notion ───────────────────────────────────────────────────────────────────
NOTION_CONNECTOR_ENABLED    = true
NOTION_DEFAULT_DATABASE     = ""                                 # ID de base de datos principal

# ── Linear ───────────────────────────────────────────────────────────────────
LINEAR_CONNECTOR_ENABLED    = true
LINEAR_DEFAULT_TEAM         = ""                                 # Equipo Linear por defecto

# ── Figma ────────────────────────────────────────────────────────────────────
FIGMA_CONNECTOR_ENABLED     = true
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
2. Activar el conector en claude.ai/settings/connectors (1 clic + OAuth)
3. Los Connectors se sincronizan automáticamente con Claude Code — no hay paso adicional
4. Configurar los valores del proyecto en su CLAUDE.md

Para herramientas sin Connector oficial (ej: Azure DevOps), usar `claude mcp add` en terminal.
Ver `docs/recommended-mcps.md` para el catálogo completo.

Si un conector no está activado y un comando intenta usarlo, mostrar:
```
⚠️ El conector {nombre} no está activado.
Actívalo en: claude.ai/settings/connectors
Para Azure DevOps u otros sin Connector: claude mcp add --transport stdio {nombre} -- {comando}
```
