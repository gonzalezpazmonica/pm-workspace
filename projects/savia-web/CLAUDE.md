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
MARKDOWN           = "marked (LinkedIn-style rendering in viewer + chat)"
AUTH               = "Per-user tokens + roles (admin/user)"
DEV_PORT           = 5173
DEV_PROTOCOL       = "HTTPS (uses Bridge certs from ~/.savia/bridge/)"
BRIDGE_DEFAULT_URL = "https://localhost:8922"
```

## Architecture

```
src/
├── composables/    ← Bridge API (get/post), SSE streaming, report fetching
├── stores/         ← Pinia stores (8): auth, dashboard, chat, reports, project, backlog, pipeline, integrations
├── types/          ← TypeScript interfaces (bridge.ts, chat.ts, reports.ts)
├── locales/        ← i18n JSON (es.json, en.json) + index.ts plugin
├── pages/          ← 13 route-level pages
├── components/     ← 28 components: backlog/(5), files/(3), charts/(10), ChatSessionList, ProjectSelector, CreateProjectModal...
├── layouts/        ← MainLayout with sidebar + topbar + role loading
├── router/         ← Vue Router with admin guard (/admin/* requires admin role)
└── styles/         ← CSS variables (Savia palette) + global styles
```

## Key Features

- **Chat**: SSE streaming with Claude via Bridge, markdown rendering in bubbles, session management (list, switch, new, delete, persist), user identity injection per message
- **Backlog**: 3-level hierarchy (Spec > PBI > Task), tree + kanban, detail panel with editing, type icons, filters (type/state/person), state persistence
- **Project Selector**: TopBar dropdown + "Create Project" modal. All stores reload on project switch
- **User Management**: Admin panel `/admin/users`. CRUD users, roles (admin/user), token rotation/revocation
- **i18n**: All pages + sidebar use `$t()`. ES+EN. Add language = add 1 JSON file
- **File Browser**: Breadcrumb, LinkedIn-style markdown viewer (tables, frontmatter card), editor for .md files
- **Pipelines**: Stage visualization, log viewer
- **n8n Hub**: Workflows, executions, setup wizard
- **Reports**: 7 sub-pages (Sprint, Board Flow, Workload, Portfolio, DORA, Quality, Debt)
- **Auth**: Per-user tokens, roles, `/auth/me`, route guard

## Rules

- All `.vue` files ≤ 150 lines
- All user-visible strings via `$t()` / `useI18n()`
- No external CSS framework (custom CSS only)
- Lucide icons only — no emoji icons in UI
- All stores watch `projectStore.selectedId` for context switch

## Testing

```bash
npm test              # Unit tests (vitest, 42 files, 228 tests)
npm run e2e           # E2E tests (playwright, 18 files, 148 tests)
npm run test:coverage # Coverage report (threshold 80%)
```

## Bridge Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/auth/me` | GET | Current user info + role |
| `/chat` | POST | Send message, SSE streaming response |
| `/sessions` | GET | List chat sessions |
| `/projects` | GET/POST | List/create projects |
| `/backlog` | GET | PBIs and tasks for project |
| `/files` | GET | Directory listing |
| `/files/content` | GET/PUT | Read/write file content |
| `/users` | GET/POST | User management (admin) |
| `/users/{slug}` | PUT/DELETE | Update/delete user (admin) |
| `/users/{slug}/rotate-token` | POST | Regenerate token |
| `/dashboard` | GET | Home page data |
| `/reports/*` | GET | Report chart data |
