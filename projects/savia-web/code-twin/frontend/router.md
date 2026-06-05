---
module_id: FrontendRouter
layer: frontend
version: "1.0.0"
last_sync: "2026-06-06T10:00:00Z"
token_budget: 250
stale_after_days: 30
depends_on:
  - FrontendStores
provides:
  - routes
  - guards
status: STABLE
---
# Frontend Router — savia-web

**Mode**: `createWebHistory()` (HTML5 pushState)
**Lazy loading**: all page components use `() => import(...)` (code splitting)

## Routes

| path | component | notes |
|------|-----------|-------|
| `/` | HomePage | |
| `/chat` | ChatPage | |
| `/commands` | CommandsPage | |
| `/backlog` | BacklogPage | |
| `/kanban` | — | redirect → `/backlog` |
| `/pipelines` | PipelinesPage | |
| `/integrations` | IntegrationsPage | |
| `/approvals` | ApprovalsPage | |
| `/timelog` | TimeLogPage | |
| `/files` | FileBrowserPage | |
| `/profile` | ProfilePage | |
| `/settings` | SettingsPage | |
| `/admin/users` | AdminUsersPage | `requiresAdmin: true` |
| `/reports` | ReportsLayout | redirect → `/reports/sprint`; 7 children |

## Guards

**beforeEach**: if `meta.requiresAdmin` → lazy-load `useAuthStore` → if `role !== 'admin'` → redirect `/`; fetches `/auth/me` if token present but role not loaded
