# Savia Web — Vue.js Client for PM-Workspace

> Web client that connects to Savia Bridge for full PM-Workspace access.

---

## Stack

```
FRAMEWORK          = "Vue 3 (Composition API, script setup)"
LANGUAGE           = "TypeScript"
BUILD_TOOL         = "Vite 6"
STATE_MANAGEMENT   = "Pinia"
ROUTING            = "Vue Router 4"
I18N               = "vue-i18n 9 (ES default, EN included, lazy loading)"
CHARTS             = "ECharts 5 + vue-echarts 7"
MARKDOWN           = "marked + highlight.js"
DEV_PORT           = 5173
DEV_PROTOCOL       = "HTTPS (uses Bridge certs from ~/.savia/bridge/)"
PROD_PORT          = 8081
BRIDGE_DEFAULT_URL = "https://localhost:8922"
```

## Architecture

```
src/
├── composables/    ← Bridge API, SSE streaming, report fetching
├── stores/         ← Pinia stores (8): auth, dashboard, chat, reports, project, backlog, pipeline, integrations
├── types/          ← TypeScript interfaces (bridge.ts, chat.ts, reports.ts)
├── locales/        ← i18n JSON (es.json, en.json) + index.ts plugin
├── pages/          ← Route-level pages (12 routes)
├── components/     ← backlog/ (4), files/ (3), charts/ (10), ProjectSelector, etc.
├── layouts/        ← MainLayout with sidebar + topbar
└── styles/         ← CSS variables (Savia palette) + global styles
```

## Key Features

- **Backlog**: 3-level hierarchy (Spec > PBI > Task), tree + kanban views, detail panel with editing (state, title, description), add PBI/task, type icons
- **Project Selector**: TopBar dropdown, loads from Bridge `/projects`, all stores watch project changes and reload
- **i18n**: All pages and sidebar use `$t()` / `useI18n()`. ES+EN. Add language = add 1 JSON file
- **File Browser**: Breadcrumb navigation, markdown render, syntax highlighting
- **Pipelines**: Stage visualization, log viewer
- **n8n Hub**: Workflows, executions, setup wizard
- **Reports**: 7 sub-pages (Sprint, Board Flow, Workload, Portfolio, DORA, Quality, Debt)

## Rules

- All `.vue` files ≤ 150 lines
- All user-visible strings via `$t()` / `useI18n()` — never hardcoded
- No external CSS framework (custom CSS only)
- Lucide icons only — no emoji icons in UI
- All stores watch `projectStore.selectedId` for context switch

## Testing

```bash
npm test              # Unit tests (vitest, 41 files, 217 tests)
npm run e2e           # E2E tests (playwright, 15 files, 109 tests)
npm run test:coverage # Coverage report (threshold 80%)
```

## Development

```bash
cd projects/savia-web
npm install
npm run dev          # https://localhost:5173 (HTTPS via Bridge certs)
```

## Release

`npm version patch|minor|major` then `vue-tsc -b && vite build`. E2E before release.
