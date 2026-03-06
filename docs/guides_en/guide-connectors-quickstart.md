# Connect external tools in 1 minute

pm-workspace integrates with external tools using MCP (Model Context Protocol). Claude Connectors are the fastest way: 1 click, OAuth managed by Anthropic, auto-synced to Claude Code immediately.

## Via Connectors (recommended)

### Step by step

1. **Open** [claude.ai/settings/connectors](https://claude.ai/settings/connectors)
2. **Find** the tool (GitHub, Slack, Jira, Notion, Sentry, Figma, Google Drive, etc.)
3. **Click** "Connect" → authorize OAuth
4. **Done** — available instantly in Claude Code, Desktop, and Mobile

**Requirement:** Pro, Max, Team, or Enterprise plan.

## Via MCP manual (for developers)

For tools without official Connectors or special environments:

```bash
claude mcp add --transport http {name} {server-url}
```

**Use cases:** Azure DevOps, Elasticsearch, custom servers, CI/CD, air-gapped environments.

## Verify your connection

In Claude Code:
- `/mcp` — Lists all connected MCP servers
- `/integration-status` — Checks pm-workspace integrations

## Configure per project

After connecting, customize values in `projects/{name}/CLAUDE.md`:

```
SLACK_DEFAULT_CHANNEL = "#my-channel"
GITHUB_DEFAULT_ORG = "my-org"
JIRA_DEFAULT_PROJECT = "PROJ"
```

See `connectors-config.md` for available constants.

## Tools with official Connectors

| Tool | Connector | Use cases |
|---|---|---|
| GitHub | github | PRs, issues, activity |
| Slack | slack | Search, notifications |
| Notion | notion | Database sync |
| Google Drive | google-drive | Report upload/download |
| Gmail | gmail | Inbox check |
| Google Calendar | google-calendar | Events, integration |
| Jira | jira | PBI management, sprints |
| Confluence | confluence | Wiki publishing |
| Figma | figma | Design export |
| Sentry | sentry | Error monitoring |
| Linear | linear | Task tracking |
| Stripe | stripe | Cost center |

**Note:** Azure DevOps requires manual MCP (no official Connector yet).

## Learn more

- 📚 [Complete Connectors guide](../recommended-mcps.md)
- 🏗️ [Architecture: Connectors vs MCP](../propuestas/adr-connectors-vs-mcp.md)
- 🔗 [Official directory](https://claude.com/connectors)
