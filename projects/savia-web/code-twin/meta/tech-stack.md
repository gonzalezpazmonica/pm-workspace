---
module_id: TechStack
layer: cross-cutting
version: "1.0.0"
last_sync: "2026-06-06T10:00:00Z"
token_budget: 200
stale_after_days: 90
depends_on: []
provides:
  - Vue3
  - Pinia
  - Vite
  - TypeScript
status: STABLE
---
# Tech Stack — savia-web

**Runtime**: Vue 3 (Composition API) · TypeScript 5 · Vite 5
**State**: Pinia (setup stores, no options API)
**HTTP**: Fetch API via `useBridge()` composable · Bearer token auth
**Routing**: Vue Router 4 · lazy-loaded pages · `meta.requiresAdmin` guard
**Testing**: Vitest · Vue Test Utils
**Build output**: SPA served as static assets
