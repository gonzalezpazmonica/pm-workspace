# Spec: Savia Web — n8n Integration Hub

## Metadatos
- project: savia-web
- phase: 2 — Savia Web Core
- feature: n8n-integration-hub
- status: pending
- developer_type: human
- depends: savia-web-mvp (Bridge connection)

## Objective

Provide a visual interface for managing external integrations via n8n (FOSS, self-hosted workflow automation). Non-programmers can connect Savia to Slack, email, calendars, CRMs, and 400+ services without writing code. This is the Savia equivalent of Zapier/Make, but using FOSS infrastructure.

## Architecture

### Route: `/integrations`

### n8n connection

n8n runs self-hosted (Docker or native). Savia Web connects to its REST API:

```
n8n API base: http://localhost:5678/api/v1
Auth: X-N8N-API-KEY header (stored in Bridge config)
```

Bridge acts as proxy to n8n API (avoids CORS, adds auth):

```
GET  /integrations/workflows         → n8n GET /workflows
GET  /integrations/workflows/{id}    → n8n GET /workflows/{id}
POST /integrations/workflows/{id}/activate    → n8n POST activate
POST /integrations/workflows/{id}/deactivate  → n8n POST deactivate
GET  /integrations/workflows/{id}/executions  → n8n GET executions
GET  /integrations/templates         → Local templates from Savia
POST /integrations/workflows/import  → n8n POST /workflows (from template)
```

### FOSS alternatives supported

| Tool | License | Notes |
|------|---------|-------|
| n8n | Sustainable Use License | Primary. Self-hosted free |
| Automatisch | Apache 2.0 | 100% FOSS alternative |
| Activepieces | MIT | 100% FOSS alternative |

Bridge config determines which backend. API abstraction layer adapts.

## Functional Requirements

### FR-01: Integration Dashboard

Overview page showing:
- Connection status to n8n (green/red indicator)
- Active workflows count
- Recent executions (last 10) with status
- Button "Setup n8n" if not connected (guides to Docker setup)

### FR-02: Workflow List

Table of all workflows:

| Column | Description |
|--------|-------------|
| Name | Workflow name |
| Status | Active / Inactive (toggle switch) |
| Last execution | Timestamp + status (success/error) |
| Trigger | Cron / Webhook / Manual |
| Actions | Edit in n8n / View executions / Delete |

Toggle switch activates/deactivates workflows inline.

### FR-03: Savia Templates

Pre-built workflow templates for common PM scenarios:

| Template | Trigger | Action |
|----------|---------|--------|
| Sprint Status → Slack | Cron (daily 9:15) | POST sprint summary to Slack channel |
| Blocked Items Alert | Cron (every 2h) | Check for blocked PBIs, notify @PM via email |
| PBI State Change → Notification | Webhook | When PBI moves to Done, notify team |
| New PBI → Jira Sync | Webhook | Create mirror Jira issue when PBI created |
| Deployment Complete → Chat | Webhook | Post deployment result to Google Chat |
| Weekly Burndown → Email | Cron (Friday 17:00) | Generate and email burndown report |

Each template: name, description, required credentials, preview (read-only n8n canvas), "Install" button.

Install flow:
1. User clicks "Install"
2. Modal shows required credentials (e.g., Slack webhook URL)
3. User fills in credentials
4. Savia imports workflow to n8n via API
5. Workflow appears in list as Inactive
6. User toggles Active when ready

### FR-04: Execution Log

Click workflow → execution history:
- List of runs with timestamp, duration, status (success/error)
- Click run → shows step-by-step execution with input/output per node
- Error details with stack trace for failed runs
- Retry button for failed executions

### FR-05: n8n Canvas Link

Button "Edit in n8n" opens the n8n web editor in a new tab for the selected workflow. For users who want full control over workflow logic.

### FR-06: Setup Wizard

If n8n is not detected, show guided setup:
1. Check if Docker is available
2. Offer one-click n8n deploy: `docker run -d --name n8n -p 5678:5678 n8nio/n8n`
3. Wait for n8n health check
4. Generate API key
5. Save connection to Bridge config
6. Show "Connected" status

## Non-Functional Requirements

- NFR-01: All `.vue` files <= 150 lines
- NFR-02: Works without n8n (page shows setup wizard, not error)
- NFR-03: Template import is idempotent (re-import updates, doesn't duplicate)
- NFR-04: Credentials entered in UI are stored in n8n, not in Savia
- NFR-05: Zero vendor lock-in — n8n is self-hosted, data stays local
- NFR-06: If n8n is unreachable, show cached last-known state

## Vue Components (estimated)

```
src/pages/IntegrationsPage.vue
src/components/integrations/
  IntegrationDashboard.vue
  WorkflowList.vue
  WorkflowRow.vue
  TemplateGallery.vue
  TemplateCard.vue
  TemplateInstallModal.vue
  ExecutionLog.vue
  ExecutionDetail.vue
  N8nSetupWizard.vue
src/stores/integrations.ts
src/composables/useIntegrations.ts
src/types/integrations.ts
```

## Acceptance Criteria

- [ ] AC-1: Dashboard shows n8n connection status and active workflow count
- [ ] AC-2: Workflow list shows all n8n workflows with toggle activate/deactivate
- [ ] AC-3: Template gallery shows 6 Savia templates with "Install" button
- [ ] AC-4: Installing a template creates the workflow in n8n and shows in list
- [ ] AC-5: Execution log shows run history with status per step
- [ ] AC-6: "Edit in n8n" opens n8n editor in new tab for the workflow
- [ ] AC-7: Setup wizard deploys n8n via Docker if not present
- [ ] AC-8: Non-programmer can install a "Blocked Alert → Slack" template without code
- [ ] AC-9: Page works gracefully when n8n is not installed (shows wizard, not error)
