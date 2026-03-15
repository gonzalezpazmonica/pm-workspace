# Savia Web — Vue.js Client for PM-Workspace

> Web client that connects to Savia Bridge for full PM-Workspace access.

---

## Stack

```
FRAMEWORK          = "Vue 3 (Composition API, script setup)"
LANGUAGE           = "TypeScript"
BUILD_TOOL         = "Vite 6"
STATE_MANAGEMENT   = "Pinia"
ROUTING            = "Vue Router 4 (admin route guard)"
I18N               = "vue-i18n 9 (ES default, EN included)"
CHARTS             = "ECharts 5 + vue-echarts 7"
MARKDOWN           = "marked (LinkedIn-style rendering)"
AUTH               = "Per-user tokens + roles (admin/user)"
DEV_PORT           = 5173
DEV_PROTOCOL       = "HTTPS (uses Bridge certs from ~/.savia/bridge/)"
PROD_PORT          = 8081
BRIDGE_DEFAULT_URL = "https://localhost:8922"
```

## Architecture

```
src/
├── composables/    ← Bridge API (get/post), SSE streaming, report fetching
├── stores/         ← Pinia stores (8): auth, dashboard, chat, reports, project, backlog, pipeline, integrations
├── types/          ← TypeScript interfaces (bridge.ts, chat.ts, reports.ts)
├── locales/        ← i18n JSON (es.json, en.json) + index.ts plugin
├── pages/          ← 13 route-level pages (incl. AdminUsersPage)
├── components/     ← backlog/ (5), files/ (3), charts/ (10), ProjectSelector, CreateProjectModal, etc.
├── layouts/        ← MainLayout with sidebar + topbar + role loading
├── router/         ← Vue Router with admin guard (/admin/* requires admin role)
└── styles/         ← CSS variables (Savia palette) + global styles
```

## Key Features

- **Backlog**: 3-level hierarchy (Spec > PBI > Task), tree + kanban views, detail panel with editing (state, title, description), add PBI/task, type icons (BookOpen, Bug, Wrench, Lightbulb, ListTodo, FileText), filters (type/state/person), state persistence (localStorage)
- **Project Selector**: TopBar dropdown + "Create Project" button. Loads from Bridge `/projects`. All stores watch project changes and reload
- **User Management**: Admin-only panel at `/admin/users`. Create/edit/delete users, role management (admin/user), token rotation/revocation. Per-user auth tokens
- **i18n**: All 13 pages + sidebar use `useI18n()` / `$t()`. ES+EN. Add language = add 1 JSON file
- **File Browser**: Breadcrumb navigation, LinkedIn-style markdown render (tables, frontmatter card, blockquotes), edit mode for .md files (save via Bridge)
- **Pipelines**: Stage visualization, log viewer, mock data
- **n8n Hub**: Workflows, executions, setup wizard, mock data
- **Reports**: 7 sub-pages (Sprint, Board Flow, Workload, Portfolio, DORA, Quality, Debt)
- **Auth**: Per-user tokens, admin/user roles, `/auth/me` for role detection, route guard for admin pages

## Pages (13 routes + 7 report sub-routes)

| Route | Page | Access |
|-------|------|--------|
| `/` | HomePage | all |
| `/chat` | ChatPage | all |
| `/commands` | CommandsPage | all |
| `/backlog` | BacklogPage | all |
| `/pipelines` | PipelinesPage | all |
| `/integrations` | IntegrationsPage | all |
| `/files` | FileBrowserPage | all (admin sees root, users see projects/) |
| `/reports/*` | 7 sub-pages | all |
| `/settings` | SettingsPage | all |
| `/profile` | ProfilePage | all |
| `/approvals` | ApprovalsPage | all |
| `/timelog` | TimeLogPage | all |
| `/admin/users` | AdminUsersPage | **admin only** |

## Rules

- All `.vue` files ≤ 150 lines — split into sub-components
- All user-visible strings via `$t()` / `useI18n()` — never hardcoded
- No external CSS framework (custom CSS only)
- Lucide icons only — no emoji icons in UI
- All stores watch `projectStore.selectedId` for context switch
- Admin routes require `role === 'admin'` (route guard)

## Testing

```bash
npm test              # Unit tests (vitest, 42 files, 228 tests)
npm run e2e           # E2E tests (playwright, 17 files, 130 tests)
npm run test:coverage # Coverage report (threshold 80%)
```

## Bridge Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/auth/me` | GET | Current user info + role |
| `/projects` | GET/POST | List/create projects |
| `/backlog` | GET | PBIs and tasks for project |
| `/files` | GET | Directory listing |
| `/files/content` | GET/PUT | Read/write file content |
| `/users` | GET/POST | User management (admin) |
| `/users/{slug}` | PUT/DELETE | Update/delete user (admin) |
| `/users/{slug}/rotate-token` | POST | Regenerate token |
| `/dashboard` | GET | Home page data |
| `/reports/*` | GET | Report chart data |

## Development

```bash
cd projects/savia-web
npm install
npm run dev          # https://localhost:5173 (HTTPS via Bridge certs)
```

## Release

`npm version patch|minor|major` then `vue-tsc -b && vite build`. E2E before release.
