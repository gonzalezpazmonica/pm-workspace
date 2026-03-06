# Catálogo de Integraciones para pm-workspace

pm-workspace se conecta a herramientas externas mediante MCP (Model Context Protocol). Hay dos vías para activar integraciones: Claude Connectors (1 clic, recomendado) y MCP servers community (terminal).

## Vía 1: Claude Connectors (recomendado)

Los Connectors son MCP servers revisados por Anthropic con OAuth gestionado. Se activan en [claude.ai/settings/connectors](https://claude.ai/settings/connectors) y quedan disponibles automáticamente en Claude Code, Claude Desktop y Claude Mobile.

**Requisito:** Plan Pro, Max, Team o Enterprise.

| Herramienta | Connector oficial | Comandos pm-workspace que lo usan |
|---|---|---|
| GitHub | github | `/github-issues`, `/github-activity`, `/repos-*`, `/security-alerts` |
| Slack | slack | `/slack-search`, `/notify-slack`, `/inbox-check` |
| Notion | notion | `/notion-sync` |
| Google Drive | google-drive | `/gdrive-upload` |
| Gmail | gmail | `/inbox-check` |
| Google Calendar | google-calendar | `/court-calendar` (integración ICS) |
| Jira | jira | `/jira-sync` |
| Confluence | confluence | `/confluence-publish`, `/wiki-sync`, `/wiki-publish` |
| Figma | figma | `/figma-extract` |
| Sentry | sentry | `/sentry-bugs`, `/sentry-health` |
| Linear | linear | `/integration-status` |
| Stripe | stripe | `/cost-center` (facturación) |

**Cómo activar:** Ver [Guía rápida de Connectors](guides/guide-connectors-quickstart.md).

---

## Vía 2: MCP Servers Community (terminal)

Para herramientas sin Connector oficial, o entornos que requieren configuración local (CI/CD, air-gapped, Azure DevOps).

### Instalación

```bash
# Opción A: Desde claude-code-templates
npx claude-code-templates@latest --mcp {categoria}/{nombre} --yes

# Opción B: Directo con claude mcp add
claude mcp add --transport http nombre https://url-del-server
```

### Azure DevOps (sin Connector oficial)

La integración con Azure DevOps requiere MCP community. Ver `.claude/rules/domain/mcp-migration.md` para el mapeo completo REST → MCP.

```bash
claude mcp add --transport stdio azure-devops -- npx -y azure-devops-mcp-server
```

Comandos que lo usan: `/sprint-status`, `/pipeline-*`, `/repos-*`, `/board-view`.

### Base de Datos

**neon-postgres** — PostgreSQL serverless para almacenamiento de sprints y tareas.
`npx claude-code-templates@latest --mcp database/neon-postgres --yes`

**supabase** — Backend-as-a-service con autenticación y APIs en tiempo real.
`npx claude-code-templates@latest --mcp database/supabase --yes`

**mysql** — Integración con bases de datos MySQL heredadas.
`npx claude-code-templates@latest --mcp database/mysql --yes`

### DevTools

**terraform** — Infraestructura como código para automatización de ambientes.
`npx claude-code-templates@latest --mcp devtools/terraform --yes`

**elasticsearch** — Motor de búsqueda para exploración de logs y métricas.
`npx claude-code-templates@latest --mcp devtools/elasticsearch --yes`

### Automatización de Navegadores

**playwright** — Pruebas E2E con soporte Chrome, Firefox y WebKit.
`npx claude-code-templates@latest --mcp browser_automation/playwright --yes`

**puppeteer** — Automatización headless Chrome para testing y scraping.
`npx claude-code-templates@latest --mcp browser_automation/puppeteer --yes`

### Investigación

**mcp-server-nia** — Investigación profunda para discovery de productos.
`npx claude-code-templates@latest --mcp deepresearch/mcp-server-nia --yes`

---

## Explorar más

- **Directorio oficial de Connectors:** [claude.ai/connectors](https://claude.com/connectors)
- **Catálogo claude-code-templates:** [aitmpl.com](https://aitmpl.com) (66+ servers)
- **Registro MCP de Anthropic:** disponible via `claude mcp add` con autocompletado
- **Comando pm-workspace:** `/mcp-browse` para explorar MCPs desde la terminal
