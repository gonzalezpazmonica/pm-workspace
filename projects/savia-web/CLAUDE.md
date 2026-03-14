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
CHARTS             = "ECharts 5 + vue-echarts 7"
MARKDOWN           = "marked + highlight.js"
DEV_PORT           = 5173
PROD_PORT          = 8081
BRIDGE_DEFAULT_URL = "https://localhost:8922"
```

## Architecture

```
src/
├── composables/    ← Bridge API, SSE streaming, report fetching
├── stores/         ← Pinia stores (auth, dashboard, chat, reports)
├── types/          ← TypeScript interfaces matching Bridge/Kotlin models
├── pages/          ← Route-level page components
├── components/     ← Reusable UI components and ECharts wrappers
├── layouts/        ← MainLayout with sidebar + topbar
└── styles/         ← CSS variables (Savia palette) + global styles
```

## Development

```bash
cd projects/savia-web
npm install
npm run dev          # http://localhost:5173 with HMR
```

## Production

```bash
bash scripts/setup-savia-web.sh   # Build + serve on :8081
```

## Bridge Connection

Settings page configures Bridge host/port/token (persisted in localStorage).
All API calls go through `composables/useBridge.ts`.
Chat uses SSE streaming via `composables/useSSE.ts`.

## Design System

Savia violet/mauve palette from Color.kt:
- Primary: `#6B4C9A` (deep violet)
- Surface: `#FFFFFF` / `#211F26` (dark)
- Accent: `#CDB4DB` (light mauve)

CSS custom properties in `styles/variables.css`. Dark mode via `[data-theme="dark"]`.

## Rules

- All `.vue` files ≤ 150 lines
- One chart component per file
- Types mirror Kotlin domain models
- No external CSS framework (custom CSS only)
- All dependencies must be open source (MIT, ISC, Apache, SIL OFL)
- Lucide icons only — no emoji icons in UI

## Release Policy

Version in `package.json` is the single source of truth.
Injected at build time via Vite `define` → `__APP_VERSION__`.
Shown in sidebar footer: "Savia Web v{version}".

```
RELEASE_CHANNEL    = "local"
VERSION_SOURCE     = "package.json"
VERSION_BUMP       = "npm version patch|minor|major"
```

**On every build/change:**
1. Bump version: `npm version patch` (auto-increments)
2. Build: `npm run build` (version baked into bundle)
3. Run E2E regression: `npm run e2e`
4. Serve: `npm run serve`

**Versioning:** semver — patch for fixes, minor for features, major for breaking.

## Testing

```bash
npm test              # Unit tests (vitest, 32 files)
npm run e2e           # E2E tests (playwright, 10 files)
npm run test:coverage # Coverage report (threshold 80%)
```

Regression plan: `specs/regression-plan.md`
