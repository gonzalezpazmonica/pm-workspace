---
globs: [".claude/commands/**"]
---
# Tool Search Configuration — MCP Tool Discovery

Intelligent tool discovery for 400+ commands when they exceed context limits. Auto-categorization, keyword routing, and usage-based prioritization.

## Activation

Auto-enable tool search when **tools exceed 128 in context window**. Manual activation: `/tool-search {query}`.

## Tool Categories

**PM Operations** (pbi-*, sprint-*, capacity-*, project-*)
- Sprint planning, board management, capacity forecasting, project oversight
- Keywords: sprint, daily, velocity, board, capacity, project

**Development** (spec-*, dev-*, arch-*, code-*)
- Specifications, architecture, coding, design patterns
- Keywords: spec, architecture, code, design, implementation

**Infrastructure** (infra-*, pipeline-*, deploy-*, env-*)
- Deployment, pipelines, environments, infrastructure as code
- Keywords: deploy, pipeline, infra, environment, kubernetes

**Reporting** (report-*, audit-*, track-*, metric-*)
- Audits, metrics, dashboards, analytical reports
- Keywords: report, audit, metric, dashboard, dora

**Communication** (scheduled-*, notify-*, chat-*)
- Notifications, messaging, scheduled tasks, team communication
- Keywords: notify, message, slack, chat, scheduled

**Compliance** (security-*, compliance-*, aepd-*, equality-*)
- Security, regulatory, GDPR, equality audits
- Keywords: security, compliance, gdpr, aepd, equality

**Discovery** (discovery-*, jtbd-*, prd-*, rules-*)
- Product discovery, jobs-to-be-done, requirements analysis
- Keywords: discovery, jtbd, prd, rules, requirements

**Admin** (plugin-*, agent-*, profile-*, config-*)
- Configuration, plugins, profiles, agents management
- Keywords: plugin, agent, profile, config, setup

## Routing Heuristics

1. **Keyword matching** (40%): Search user request for category keywords
2. **Category selection** (40%): Load 20-30 tools from top category
3. **Top-20 algorithm** (20%): Most-used tools always available

## Fallback Strategy

If no category matches:
- Load top 20 most-used commands from usage history
- Load skill list (brief: name + 1-line description)
- Suggest `/tool-catalog` for full navigation

## Usage Tracking

Maintain `data/tool-usage.jsonl` with fields: command, count, last_used, category.
Update after each successful command execution.

