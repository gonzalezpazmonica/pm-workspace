# Conectar herramientas externas en 1 minuto

pm-workspace se integra con herramientas externas usando MCP (Model Context Protocol). Los Claude Connectors son la forma más rápida: 1 clic, OAuth gestionado por Anthropic, autosincronización inmediata a Claude Code.

## Vía Connectors (recomendado)

### Paso a paso

1. **Abre** [claude.ai/settings/connectors](https://claude.ai/settings/connectors)
2. **Busca** la herramienta (GitHub, Slack, Jira, Notion, Sentry, Figma, Google Drive, etc.)
3. **Haz clic** en "Conectar" → autoriza OAuth
4. **Listo** — disponible inmediatamente en Claude Code, Desktop y Mobile

**Requisito:** Plan Pro, Max, Team o Enterprise.

## Vía MCP manual (para desarrolladores)

Para herramientas sin Connector oficial o entornos especiales:

```bash
claude mcp add --transport http {nombre} {url-del-server}
```

**Casos de uso:** Azure DevOps, Elasticsearch, servidores personalizados, CI/CD, entornos desconectados.

## Verifica la conexión

En Claude Code:
- `/mcp` — Lista todos los servidores MCP conectados
- `/integration-status` — Comprueba integraciones de pm-workspace

## Configura por proyecto

Después de conectar, personaliza valores en `projects/{nombre}/CLAUDE.md`:

```
SLACK_DEFAULT_CHANNEL = "#mi-canal"
GITHUB_DEFAULT_ORG = "mi-org"
JIRA_DEFAULT_PROJECT = "PROJ"
```

Ver `connectors-config.md` para las constantes disponibles.

## Herramientas con Connector oficial

| Herramienta | Conector | Casos de uso |
|---|---|---|
| GitHub | github | PRs, issues, actividad |
| Slack | slack | Búsqueda, notificaciones |
| Notion | notion | Sincronización de bases de datos |
| Google Drive | google-drive | Descarga/subida de informes |
| Gmail | gmail | Verificación de bandeja entrada |
| Google Calendar | google-calendar | Eventos, integraciones |
| Jira | jira | Gestión de PBIs, sprints |
| Confluence | confluence | Publicación de wikis |
| Figma | figma | Exportación de diseños |
| Sentry | sentry | Monitoreo de errores |
| Linear | linear | Seguimiento de tareas |
| Stripe | stripe | Centro de costos |

**Nota:** Azure DevOps requiere MCP manual (sin Connector oficial aún).

## Referencias

- 📚 [Guía completa de Connectors](../recommended-mcps.md)
- 🏗️ [Arquitectura: Connectors vs MCP](../propuestas/adr-connectors-vs-mcp.md)
- 🔗 [Directorio oficial](https://claude.com/connectors)
