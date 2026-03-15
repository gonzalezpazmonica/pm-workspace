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
I18N               = "vue-i18n 9 (Composition API, lazy loading)"
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
├── stores/         ← Pinia stores (auth, dashboard, chat, reports, project, backlog, pipeline, integrations)
├── types/          ← TypeScript interfaces (bridge.ts, chat.ts, reports.ts)
├── locales/        ← i18n JSON files (es.json, en.json) + index.ts plugin
├── pages/          ← Route-level pages (12 routes)
├── components/     ← Reusable UI: backlog/, files/, charts/, ProjectSelector
├── layouts/        ← MainLayout with sidebar + topbar
└── styles/         ← CSS variables (Savia palette) + global styles
```

## Development

```bash
cd projects/savia-web
npm install
npm run dev          # https://localhost:5173 with HMR (HTTPS via Bridge certs)
```

## Bridge Connection

Settings page configures Bridge host/port/token (persisted in localStorage).
All API calls go through `composables/useBridge.ts`.
Bridge endpoints: `/projects`, `/backlog`, `/files`, `/reports/*`, `/dashboard`, `/chat`.

## Design System

Savia violet/mauve palette. CSS custom properties in `styles/variables.css`.
Dark mode via `[data-theme="dark"]`. Lucide icons only.

## Rules

- All `.vue` files ≤ 150 lines — split into sub-components
- No external CSS framework (custom CSS only)
- All dependencies open source (MIT, ISC, Apache, SIL OFL)
- Lucide icons only — no emoji icons in UI
- All user-visible strings via `$t()` / `useI18n()` (i18n keys in locales/)

## Pages (12 routes)

| Route | Page | Spec |
|-------|------|------|
| `/` | HomePage | Dashboard with KPIs, tasks, activity |
| `/chat` | ChatPage | SSE streaming chat with Claude |
| `/commands` | CommandsPage | Slash command browser |
| `/backlog` | BacklogPage | Tree + Kanban views, PBI detail (4 tabs) |
| `/pipelines` | PipelinesPage | Pipeline runs, stages, log viewer |
| `/integrations` | IntegrationsPage | n8n workflows, executions, setup wizard |
| `/files` | FileBrowserPage | Breadcrumb + tree + markdown viewer |
| `/reports/*` | 7 sub-pages | Sprint, Board Flow, Workload, Portfolio, DORA, Quality, Debt |
| `/settings` | SettingsPage | Bridge connection + language selector |

## Testing

```bash
npm test              # Unit tests (vitest, 41 files, 214 tests)
npm run e2e           # E2E tests (playwright, 14 files, 96 tests)
npm run test:coverage # Coverage report (threshold 80%)
```

## Release Policy

Version in `package.json` — semver. `npm version patch|minor|major`.
Build: `vue-tsc -b && vite build`. E2E before release.
