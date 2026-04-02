# Savia Model 01 — Vue 3 SPA

> Stack: Vue 3 + TypeScript + Vite | Architecture: SPA | Scale: Small-Growth (2-20)
> Exemplar: savia-web | Status: v1.0 — 2026-04-02

---

## 1. Philosophy and Culture

### Why This Model Exists

Vue 3 with the Composition API and TypeScript is the dominant pattern for
progressive SPAs that need to scale from a prototype to a production-grade
application without a rewrite. This model codifies how to build Vue SPAs
that are fast, safe, testable, and agent-friendly.

### Core Beliefs

**Composition API only.** The Options API is not used, not even partially.
Every component uses `<script setup lang="ts">`. This is not a preference
but a structural decision: `<script setup>` produces less code, enables
better TypeScript inference, eliminates `this` ambiguity, and aligns with
the composable extraction pattern that keeps components under 150 lines.

**TypeScript strict mode, no exceptions.** `strict: true` in tsconfig with
`noUncheckedIndexedAccess: true`. Every `any` is a code review rejection.
If a library lacks types, write a `.d.ts` declaration file. The type system
is the first layer of defense against runtime errors and the primary
documentation mechanism for API contracts.

**Optimized for change velocity.** The architecture prioritizes the speed
at which a developer (human or AI) can add a feature end-to-end: read a
spec, find the right layer, write the code, write the test, ship. Every
structural decision serves this goal. Clever abstractions that slow
comprehension are rejected in favor of explicit, boring patterns.

**Ship less JavaScript.** The performance budget is 200KB gzipped for the
initial load. Every dependency is justified by business value. Tree-shaking
and code-splitting are not optimizations but requirements. The build
configuration is production-grade from day one.

### Trade-offs Accepted

- Explicit over DRY: repeated patterns across stores/composables are
  preferred over premature abstractions that obscure data flow.
- Flat over nested: three levels of component nesting maximum. Beyond that,
  extract to a composable or a new route-level page.
- Colocation over centralization: test files live next to source files.
  Types live in the module that owns them, not in a global barrel.

---

## 2. Architecture Principles

### The 6-Layer Separation

```
views/       → Route-level pages. Orchestrate layout and data fetching.
components/  → Reusable UI. Pure rendering, no direct API calls.
composables/ → Stateful logic. API calls, SSE, computed derivations.
stores/      → Pinia stores. Global state, cross-component communication.
services/    → HTTP clients, WebSocket handlers, external integrations.
types/       → TypeScript interfaces, enums, API response shapes.
```

### Dependency Direction (strict, never inverted)

```
views → components → composables → stores → services → types
  |         |              |           |         |
  +-------- + ----------- + --------- + --------+--→ types (any layer reads types)
```

Rules:
- **Components never import stores directly.** They receive data via props
  and emit events. The parent view or composable bridges the store.
- **Composables may use stores.** A composable like `useBacklog()` reads
  from the backlog store and provides a filtered, reactive API to views.
- **Services are pure functions.** They take parameters, call HTTP, return
  typed responses. No reactivity, no refs, no Vue dependencies.
- **Stores never call other stores.** Cross-store coordination happens in
  composables or views. This prevents circular dependencies and makes
  stores independently testable.

### State Management Philosophy

State lives in the narrowest scope possible:

| Scope | Mechanism | Example |
|-------|-----------|---------|
| Template-local | `ref()` / `reactive()` in `<script setup>` | Form field values, toggle states |
| Component tree | `provide` / `inject` | Theme, layout config |
| Feature-global | Pinia store | Auth state, project selection |
| Server-synced | Composable + store | Backlog items, chat sessions |

Pinia stores are the single source of truth for server-synchronized state.
Components never cache API responses in local refs if the data should be
shared. If two components need the same data, it belongs in a store.

### Routing

Vue Router 4 with lazy-loaded route components. Every route beyond the
shell is a dynamic `() => import()`. Navigation guards live in the router
file, not scattered in components. Auth guards use the auth store's
`isAuthenticated` getter, never raw token checks.

---

## 3. Project Structure

```
src/
├── assets/                      Static assets (images, fonts, favicon)
│   └── styles/
│       ├── variables.css        CSS custom properties (palette, spacing, typography)
│       ├── reset.css            Minimal reset (box-sizing, margin, font)
│       └── global.css           Global utility classes, scrollbar, transitions
├── components/                  Reusable UI components
│   ├── common/                  Buttons, inputs, modals, spinners, badges
│   ├── charts/                  ECharts wrappers (typed props, responsive)
│   ├── backlog/                 Backlog-specific components (tree, kanban card)
│   ├── chat/                    Chat bubbles, session list, tool activity feed
│   └── files/                   File browser, markdown viewer, editor
├── composables/                 Stateful logic (use* prefix)
│   ├── useBridge.ts             HTTP GET/POST to Bridge API
│   ├── useSSE.ts                Server-Sent Events with cancellation
│   ├── useReports.ts            Report fetching and caching
│   ├── useAuth.ts               Login, logout, token refresh
│   └── useI18n.ts               Locale switching wrapper
├── layouts/                     Page layouts
│   └── MainLayout.vue           Sidebar + TopBar + router-view
├── locales/                     i18n translation files
│   ├── es.json                  Spanish (default)
│   ├── en.json                  English
│   └── index.ts                 vue-i18n plugin configuration
├── pages/                       Route-level views (one per route)
│   ├── HomePage.vue
│   ├── ChatPage.vue
│   ├── BacklogPage.vue
│   ├── FilesPage.vue
│   ├── ReportsPage.vue
│   ├── PipelinesPage.vue
│   ├── ApprovalsPage.vue
│   ├── SettingsPage.vue
│   └── admin/
│       └── UsersPage.vue
├── router/                      Vue Router configuration
│   └── index.ts                 Routes, guards, lazy imports
├── services/                    Pure HTTP clients (no Vue reactivity)
│   ├── api.ts                   Axios/fetch wrapper with interceptors
│   └── bridge.ts                Bridge-specific endpoints
├── stores/                      Pinia stores (one per domain)
│   ├── auth.ts                  useAuthStore — user, token, roles
│   ├── dashboard.ts             useDashboardStore — KPIs, widgets
│   ├── chat.ts                  useChatStore — sessions, messages, streaming
│   ├── backlog.ts               useBacklogStore — items, filters, tree
│   ├── project.ts               useProjectStore — active project, list
│   ├── reports.ts               useReportsStore — report data, loading
│   ├── pipeline.ts              usePipelineStore — builds, deployments
│   └── integrations.ts          useIntegrationsStore — connector status
├── types/                       TypeScript type definitions
│   ├── api.ts                   API response/request shapes
│   ├── backlog.ts               BacklogItem, BacklogFilter, BacklogState
│   ├── chat.ts                  ChatMessage, ChatSession, StreamEvent
│   ├── project.ts               Project, ProjectConfig
│   └── auth.ts                  User, Role, AuthState
├── App.vue                      Root component (router-view + global providers)
├── main.ts                      App bootstrap (createApp, plugins, mount)
├── env.d.ts                     Vite env type declarations
└── shims-vue.d.ts               Vue SFC module declaration
```

### File Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Component | PascalCase.vue | `BacklogTree.vue` |
| Composable | camelCase with `use` prefix | `useBacklog.ts` |
| Store | camelCase | `backlog.ts` (exports `useBacklogStore`) |
| Service | camelCase | `api.ts` |
| Type file | camelCase | `backlog.ts` |
| Test file | Co-located `.test.ts` | `BacklogTree.test.ts` |
| E2E test | `*.spec.ts` in `e2e/` | `backlog.spec.ts` |

### Path Aliases (vite.config.ts + tsconfig.json)

```typescript
// vite.config.ts
resolve: {
  alias: {
    '@': fileURLToPath(new URL('./src', import.meta.url)),
  },
}
```

Always import with `@/`: `import { useBacklogStore } from '@/stores/backlog'`.
Never use relative paths that climb more than one level (`../../` is banned).

---

## 4. Code Patterns

### Component Pattern: script setup + typed props/emits

```vue
<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  title: string
  count?: number
  variant?: 'primary' | 'secondary'
}

const props = withDefaults(defineProps<Props>(), {
  count: 0,
  variant: 'primary',
})

const emit = defineEmits<{
  select: [id: string]
  close: []
}>()

const displayCount = computed(() =>
  props.count > 99 ? '99+' : String(props.count),
)
</script>

<template>
  <div :class="['card', `card--${variant}`]" @click="emit('select', title)">
    <h3>{{ title }}</h3>
    <span class="badge">{{ displayCount }}</span>
  </div>
</template>
```

Rules:
- Props interface defined inline with `defineProps<Props>()`. No runtime
  validation objects — TypeScript is the validator.
- Emits use the tuple syntax for named payload typing.
- `withDefaults` for optional props with default values.
- No `defineExpose` unless the component is used with template refs by a
  parent. Exposing internals is the exception, not the norm.

### Composable Pattern

```typescript
// composables/useBacklogFilters.ts
import { ref, computed, watch } from 'vue'
import { useBacklogStore } from '@/stores/backlog'
import type { BacklogFilter } from '@/types/backlog'

export function useBacklogFilters() {
  const store = useBacklogStore()
  const activeFilter = ref<BacklogFilter>({ type: null, state: null, assignee: null })

  const filteredItems = computed(() =>
    store.items.filter((item) => {
      if (activeFilter.value.type && item.type !== activeFilter.value.type) return false
      if (activeFilter.value.state && item.state !== activeFilter.value.state) return false
      if (activeFilter.value.assignee && item.assignee !== activeFilter.value.assignee) return false
      return true
    }),
  )

  function resetFilters() {
    activeFilter.value = { type: null, state: null, assignee: null }
  }

  return { activeFilter, filteredItems, resetFilters }
}
```

Rules:
- Always return an object (not an array) for named destructuring.
- Composables that use lifecycle hooks document it in a JSDoc comment.
- Composables that accept options take a single options object parameter.
- Name starts with `use`. Always a named export, never default.

### Pinia Store: Composition Style

```typescript
// stores/auth.ts
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { api } from '@/services/api'
import type { User, Role } from '@/types/auth'

export const useAuthStore = defineStore('auth', () => {
  // --- State ---
  const user = ref<User | null>(null)
  const token = ref<string | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  // --- Getters ---
  const isAuthenticated = computed(() => token.value !== null)
  const isAdmin = computed(() => user.value?.role === 'admin')
  const displayName = computed(() => user.value?.name ?? 'Guest')

  // --- Actions ---
  async function login(credentials: { user: string; token: string }) {
    loading.value = true
    error.value = null
    try {
      const response = await api.post<{ user: User; token: string }>('/auth/login', credentials)
      user.value = response.user
      token.value = response.token
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Login failed'
      throw e
    } finally {
      loading.value = false
    }
  }

  function logout() {
    user.value = null
    token.value = null
  }

  return { user, token, loading, error, isAuthenticated, isAdmin, displayName, login, logout }
})
```

Rules:
- Always use the composition (setup function) syntax, never the options
  syntax. Composition stores have full TypeScript inference without extra
  type annotations.
- State sections clearly marked with comments: State, Getters, Actions.
- Error state lives in the store. Components read `store.error` reactively.
- Loading state lives in the store. Components read `store.loading`.
- Use `storeToRefs()` when destructuring reactive state in components to
  preserve reactivity.

### API Service Pattern

```typescript
// services/api.ts
import type { ApiResponse } from '@/types/api'

const BASE_URL = import.meta.env.VITE_BRIDGE_URL ?? 'https://localhost:8922'

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  const token = sessionStorage.getItem('bridge-token')
  if (token) headers['Authorization'] = `Bearer ${token}`

  const response = await fetch(`${BASE_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  })

  if (!response.ok) {
    const errorBody = await response.json().catch(() => ({ message: response.statusText }))
    throw new Error(errorBody.message ?? `HTTP ${response.status}`)
  }

  return response.json() as Promise<T>
}

export const api = {
  get: <T>(path: string) => request<T>('GET', path),
  post: <T>(path: string, body: unknown) => request<T>('POST', path, body),
  put: <T>(path: string, body: unknown) => request<T>('PUT', path, body),
  delete: <T>(path: string) => request<T>('DELETE', path),
}
```

Rules:
- No Axios unless the project requires interceptors, upload progress, or
  request cancellation beyond what `AbortController` provides.
- Generic return types on every method. Callers specify the expected shape.
- Auth token injected via header, never in URL query parameters.
- Errors are thrown as `Error` instances with readable messages.

### Error Handling

```typescript
// In composable or store action:
async function loadItems() {
  loading.value = true
  error.value = null
  try {
    items.value = await api.get<BacklogItem[]>('/backlog')
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Unknown error'
  } finally {
    loading.value = false
  }
}
```

Pattern: every async operation follows try/catch/finally with loading and
error state management. Components display error state via a shared
`ErrorBanner` component that reads `store.error`.

### i18n

All user-visible strings go through `vue-i18n`. No hardcoded strings in
templates. Locale files are flat JSON (no nesting deeper than 2 levels).
Keys use dot notation: `backlog.filter.type`, `chat.send.button`.

```vue
<template>
  <button>{{ $t('chat.send.button') }}</button>
</template>
```

---

## 5. Testing and Quality

### Test Pyramid

```
E2E (Playwright)      ~10%   Critical user journeys only
Component (Vitest)    ~20%   Component rendering + interaction
Unit (Vitest)         ~70%   Composables, stores, services, utils
```

### Unit Tests: Composables, Stores, Services

Framework: Vitest with `@vue/test-utils`.

```typescript
// stores/__tests__/auth.test.ts
import { setActivePinia, createPinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useAuthStore } from '@/stores/auth'

describe('useAuthStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('starts unauthenticated', () => {
    const store = useAuthStore()
    expect(store.isAuthenticated).toBe(false)
    expect(store.user).toBeNull()
  })

  it('sets user and token on login', async () => {
    const store = useAuthStore()
    vi.spyOn(global, 'fetch').mockResolvedValueOnce(
      new Response(JSON.stringify({ user: { name: 'Alice', role: 'admin' }, token: 'tok' })),
    )
    await store.login({ user: 'alice', token: 'tok' })
    expect(store.isAuthenticated).toBe(true)
    expect(store.user?.name).toBe('Alice')
  })
})
```

### Component Tests

```typescript
// components/__tests__/BacklogCard.test.ts
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import BacklogCard from '@/components/backlog/BacklogCard.vue'

describe('BacklogCard', () => {
  it('renders title and emits select on click', async () => {
    const wrapper = mount(BacklogCard, {
      props: { title: 'Implement auth', id: 'pbi-1', type: 'PBI' },
    })
    expect(wrapper.text()).toContain('Implement auth')
    await wrapper.trigger('click')
    expect(wrapper.emitted('select')).toHaveLength(1)
    expect(wrapper.emitted('select')![0]).toEqual(['pbi-1'])
  })
})
```

Rules:
- Test behavior, not implementation. Query by `data-testid`, visible text,
  or ARIA role. Never query by CSS class or internal ref name.
- One assertion focus per test. Multiple `expect` calls are fine when they
  assert the same behavior from different angles.
- Mock fetch/services at the boundary. Never mock Vue internals or Pinia
  internals.

### E2E Tests: Playwright

```typescript
// e2e/backlog.spec.ts
import { test, expect } from '@playwright/test'

test('backlog page renders items and filters', async ({ page }) => {
  await page.goto('/backlog')
  await expect(page.getByTestId('backlog-tree')).toBeVisible()
  await page.getByTestId('filter-type').selectOption('PBI')
  await expect(page.getByTestId('backlog-item')).toHaveCount(5)

  // MANDATORY: screenshot after assertions pass
  await page.screenshot({
    path: 'output/e2e-results/savia-web/backlog--filter-by-type.png',
    fullPage: true,
  })
})
```

Rules:
- Every E2E test that validates visual rendering MUST take a screenshot
  after assertions pass (per `e2e-screenshot-validation.md`).
- Screenshots go to `output/e2e-results/{project}/`.
- Use `page.route()` to mock API responses. E2E tests never hit a real
  backend unless explicitly testing integration.
- Prefer `getByTestId` > `getByRole` > `getByText`. Never use CSS
  selectors in E2E tests.

### Coverage Targets

| Layer | Target | Rationale |
|-------|--------|-----------|
| Services | 95% | Pure functions, easy to test, critical for correctness |
| Stores | 90% | State logic, all actions and getters covered |
| Composables | 85% | Core business logic |
| Components | 70% | Test rendering and interaction, skip trivial wrappers |
| Pages (views) | 50% | Integration-level, covered by E2E |
| Global minimum | 80% | Enforced by CI |

### What NOT to Test

- Third-party library behavior (ECharts rendering, vue-router internals).
- CSS styling (use visual regression via Playwright screenshots instead).
- Implementation details: internal ref values, watcher triggers, computed
  recalculation counts.
- `<template>` structure beyond what the user sees.

---

## 6. Security and Data Sovereignty

### XSS Prevention

**v-html policy: BANNED by default.** Vue auto-escapes all interpolations.
The `v-html` directive bypasses this protection. Rules:

1. `v-html` is never used with user-generated content, API responses, or
   any string that has not been sanitized.
2. If `v-html` is required (markdown rendering), the content MUST pass
   through DOMPurify with a strict allowlist configuration:

```typescript
import DOMPurify from 'dompurify'
const clean = DOMPurify.sanitize(rawHtml, {
  ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'a', 'ul', 'ol', 'li', 'code', 'pre', 'h1', 'h2', 'h3', 'table', 'thead', 'tbody', 'tr', 'th', 'td'],
  ALLOWED_ATTR: ['href', 'target', 'rel'],
})
```

3. Every use of `v-html` in the codebase must have a code review comment
   justifying its necessity and confirming sanitization.

### Auth Token Storage

**Tokens are stored in memory (Pinia store), NEVER in localStorage.**
localStorage is accessible to any JavaScript on the page, including XSS
payloads. sessionStorage is acceptable for persistence across page reloads
within a single tab. HttpOnly cookies are the gold standard when the
backend supports them.

```typescript
// Token lifecycle:
// 1. User authenticates → token stored in useAuthStore().token (ref in memory)
// 2. Page reload → re-authenticate or read from sessionStorage
// 3. Tab close → token gone (sessionStorage cleared)
// 4. Logout → token set to null, sessionStorage cleared
```

### Content Security Policy

The Vite build outputs CSP-compatible assets. The server MUST set:

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  connect-src 'self' https://localhost:8922;
  font-src 'self';
  object-src 'none';
  frame-ancestors 'none';
  base-uri 'self';
```

No `'unsafe-eval'`. If a library requires eval, replace it.
`'unsafe-inline'` for styles is acceptable for Vue's scoped styles;
use nonce-based CSP if the project requires stricter policies.

### API Validation with Zod

All API responses are validated at the service boundary:

```typescript
import { z } from 'zod'

const BacklogItemSchema = z.object({
  id: z.string(),
  title: z.string().min(1),
  type: z.enum(['Spec', 'PBI', 'Task', 'Bug']),
  state: z.string(),
  assignee: z.string().nullable(),
})

export type BacklogItem = z.infer<typeof BacklogItemSchema>

export function parseBacklogItems(data: unknown): BacklogItem[] {
  return z.array(BacklogItemSchema).parse(data)
}
```

Never trust API responses at the type level alone. TypeScript types are
compile-time only. Zod validates at runtime, catching contract violations
before they corrupt state.

### OWASP SPA Top 10 Alignment

| OWASP Risk | Mitigation |
|------------|------------|
| A03 Injection (XSS) | Vue auto-escaping, DOMPurify for v-html, CSP |
| A07 Auth Failures | Tokens in memory, short TTL, HttpOnly cookies preferred |
| A01 Broken Access Control | Route guards, role-based UI gating, server-enforced authz |
| A05 Security Misconfiguration | CSP headers, HTTPS-only, no debug in production |
| A09 Logging/Monitoring | Structured error reporting to Sentry, no PII in logs |
| A08 Software Integrity | Subresource integrity for CDN assets, lockfile pinning |
| Sensitive Data Exposure | No secrets in `VITE_` env vars, no tokens in URLs |
| CSRF | SameSite cookies, Origin header validation on API |
| Open Redirects | Validate redirect targets against allowlist |
| Dependency Vulnerabilities | `npm audit` in CI, Dependabot/Renovate enabled |

### Savia Shield Integration

When the SPA handles project data classified N4 (client-confidential),
the data-sovereignty-gate applies. The SPA itself does not classify data
(that is the backend's responsibility), but it MUST:

- Never log API response bodies to the browser console in production.
- Never persist N4 data in localStorage, IndexedDB, or service workers.
- Clear sensitive state on logout (`$reset()` on all Pinia stores).

---

## 7. DevOps and Operations

### Vite Configuration (Production)

```typescript
// vite.config.ts
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  build: {
    target: 'esnext',
    minify: 'esbuild',
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor-vue': ['vue', 'vue-router', 'pinia'],
          'vendor-echarts': ['echarts', 'vue-echarts'],
          'vendor-i18n': ['vue-i18n'],
        },
      },
    },
    chunkSizeWarningLimit: 200,
  },
})
```

### Bundle Budget

| Chunk | Max gzipped | Rationale |
|-------|-------------|-----------|
| Initial (app + vendor-vue) | 80KB | First paint budget |
| vendor-echarts | 120KB | Lazy-loaded on Reports route |
| Per-route chunk | 30KB | Code-split per page |
| Total initial load | 200KB | Target for 3G mobile |

Enforce with `build.chunkSizeWarningLimit` and CI check:

```bash
# CI step: bundle size gate
TOTAL=$(du -sb dist/assets/*.js | awk '{s+=$1} END {print s}')
MAX=512000  # 500KB uncompressed ~= 200KB gzipped
if [ "$TOTAL" -gt "$MAX" ]; then
  echo "Bundle exceeds 500KB uncompressed ($TOTAL bytes)"
  exit 1
fi
```

### CI Pipeline Stages

```
1. Install     → npm ci (locked dependencies)
2. Typecheck   → vue-tsc --noEmit
3. Lint        → eslint . --max-warnings 0
4. Unit test   → vitest run --coverage
5. Build       → vite build
6. Bundle gate → Check chunk sizes against budget
7. E2E test    → playwright test (against preview server)
8. Deploy      → Upload dist/ to hosting (staging or production)
```

Every stage is a hard gate. Failure in any stage blocks the pipeline.
E2E tests run against `vite preview` serving the production build, not
the dev server.

### Environment Builds

```bash
# .env.development
VITE_BRIDGE_URL=https://localhost:8922
VITE_LOG_LEVEL=debug

# .env.staging
VITE_BRIDGE_URL=https://staging-bridge.example.com
VITE_LOG_LEVEL=info

# .env.production
VITE_BRIDGE_URL=https://bridge.example.com
VITE_LOG_LEVEL=warn
```

`VITE_` prefix is required for client-side env vars. NEVER put secrets in
`VITE_` variables — they are embedded in the bundle and visible to anyone
who inspects the JavaScript.

### Error Tracking (Sentry Pattern)

```typescript
// main.ts
import * as Sentry from '@sentry/vue'

if (import.meta.env.PROD) {
  Sentry.init({
    app,
    dsn: import.meta.env.VITE_SENTRY_DSN,
    integrations: [Sentry.browserTracingIntegration({ router })],
    tracesSampleRate: 0.2,
    replaysSessionSampleRate: 0,
    replaysOnErrorSampleRate: 1.0,
  })
}
```

Rules:
- Only initialize in production builds.
- Sample traces at 20% to control costs.
- Capture 100% of error replays for debugging.
- Never send PII (user names, emails) in Sentry context.

---

## 8. Anti-Patterns and Guardrails

### 15 DOs

| # | DO | Rationale |
|---|-----|-----------|
| 1 | Use `<script setup lang="ts">` for every component | Eliminates boilerplate, enables full TS inference |
| 2 | Define props with `defineProps<Interface>()` | Compile-time type checking, no runtime overhead |
| 3 | Use `storeToRefs()` when destructuring store state | Preserves reactivity that raw destructuring breaks |
| 4 | Lazy-load every route with `() => import()` | Keeps initial bundle under budget |
| 5 | Put `data-testid` on every interactive element | Stable selectors for tests, resilient to refactors |
| 6 | Validate API responses with Zod at the boundary | Runtime safety against contract drift |
| 7 | Store auth tokens in memory or sessionStorage | Prevents XSS exfiltration from localStorage |
| 8 | Sanitize any HTML before `v-html` with DOMPurify | Closes the primary XSS vector in Vue apps |
| 9 | Extract logic into composables at 40+ lines | Keeps components readable and testable |
| 10 | Run `vue-tsc --noEmit` in CI before build | Catches type errors the IDE might miss |
| 11 | Write one Pinia store per domain, composition style | Clear ownership, full TS inference, no cross-store deps |
| 12 | Use `computed()` for derived state, never methods | Caching avoids redundant recalculation on re-render |
| 13 | Co-locate test files next to source files | Reduces friction to write and maintain tests |
| 14 | Pin all dependencies in package-lock.json | Reproducible builds, no surprise breaking changes |
| 15 | Take screenshots in every E2E visual assertion | Visual evidence that the UI matches the spec |

### 15 DONTs

| # | DONT | Rationale |
|---|------|-----------|
| 1 | Use Options API or mixins | Dead pattern in Vue 3; no TS inference, no tree-shaking |
| 2 | Use `any` type anywhere | Defeats the purpose of TypeScript; always find the right type |
| 3 | Put business logic in components | Components are rendering layer; logic belongs in composables/stores |
| 4 | Import stores directly in child components | Creates tight coupling; pass data via props, emit events |
| 5 | Use `v-html` with unsanitized content | Direct XSS vector; banned without DOMPurify |
| 6 | Store secrets in `VITE_` environment variables | Embedded in the bundle, visible to any browser user |
| 7 | Use `watch` with `{ immediate: true, deep: true }` | Performance killer; use `computed` or `watchEffect` instead |
| 8 | Nest components more than 3 levels deep | Creates prop drilling hell; flatten or use composables |
| 9 | Use `// @ts-ignore` or `// @ts-expect-error` without ticket | Hides problems; if needed, link to the issue being tracked |
| 10 | Call stores from other stores | Creates circular dependencies; coordinate in composables |
| 11 | Use `setTimeout`/`setInterval` without cleanup | Memory leaks; use `onUnmounted` or `effectScope` |
| 12 | Hardcode strings in templates | Breaks i18n; all user-visible text goes through `$t()` |
| 13 | Skip the loading/error state pattern in async actions | Users see blank screens; always manage loading + error refs |
| 14 | Import entire libraries when tree-shakeable submodules exist | Bloats bundle; `import { format } from 'date-fns'` not `import dayjs` |
| 15 | Use CSS `!important` | Specificity wars; fix the cascade instead of brute-forcing |

---

## 9. Agentic Integration

### Safety Classification for Vue SPA Tasks

| Task Type | Safety | Agent | Human Review |
|-----------|--------|-------|-------------|
| New component (presentational) | Low | frontend-developer | Optional |
| New page/route | Medium | frontend-developer | Recommended |
| Store creation or modification | Medium | frontend-developer | Required |
| Auth/security changes | High | frontend-developer + security-guardian | Always required |
| API service changes | Medium | frontend-developer | Required |
| Build/deploy config changes | High | frontend-developer | Always required |
| Dependency additions | High | frontend-developer | Always required |
| i18n key additions | Low | frontend-developer | Optional |
| Test creation | Low | frontend-developer | Optional |
| CSS/styling changes | Low | frontend-developer | Optional |

### Agent Prompt Template

When delegating Vue SPA work to `frontend-developer` via SDD:

```markdown
## Context
- Project: {project_name}
- Spec: {spec_path}
- Slice: {slice_number}/{total_slices}
- Files to modify: {file_list}

## Architecture Rules
- Composition API only, <script setup lang="ts">
- Props via defineProps<Interface>(), emits via defineEmits<{...}>()
- State in Pinia composition stores (ref + computed + function)
- API calls in services/, never in components
- All user-facing strings through $t()

## Quality Gates Required
- G1: vue-tsc --noEmit passes
- G2: eslint passes with 0 warnings
- G3: vitest run --coverage >= 80%
- G4: New component has co-located .test.ts
- G5: No v-html without DOMPurify
- G6: No new dependencies without justification

## Verification
After implementation, run:
1. npm run typecheck
2. npm run lint
3. npm run test -- --run
4. npm run build
```

### The 6 Quality Gates (G1-G6)

**G1 — Type Safety**: `vue-tsc --noEmit` must pass with zero errors. This
catches template type errors that `tsc` alone misses (Vue template
expressions, prop type mismatches, event payload types).

**G2 — Lint Clean**: ESLint with `@vue/eslint-config-typescript` and
`eslint-plugin-vue` recommended rules. Zero warnings policy. Formatting
handled by Prettier as a separate step (not in ESLint).

**G3 — Coverage Threshold**: Global 80% minimum enforced by Vitest
coverage configuration. Per-layer targets as defined in Section 5.

**G4 — Test Colocation**: Every new component, composable, or store
file must have a corresponding `.test.ts` file in the same directory
or a `__tests__/` subdirectory. The CI pipeline checks for orphan
source files without tests in the business logic layers.

**G5 — XSS Gate**: A grep-based pre-commit check scans for `v-html`
usage. Any new `v-html` that lacks an adjacent DOMPurify call is
flagged as a blocking finding. Existing sanitized uses are allowlisted
in `.vuexss-allowlist`.

**G6 — Dependency Gate**: `npm install` of new packages requires a
justification comment in the PR description. The CI pipeline compares
`package.json` against the previous commit and flags additions.
Bundle size is re-checked after any dependency change.

### What ALWAYS Requires Human Review

Regardless of agent confidence or automated gate results, these changes
MUST be reviewed by a human before merge:

1. **Auth flow changes** — login, logout, token refresh, role guards.
2. **Route guard modifications** — who can access what.
3. **API service URL or header changes** — attack surface modification.
4. **CSP header changes** — security policy weakening.
5. **New external dependencies** — supply chain risk.
6. **Environment variable additions** — potential secret exposure.
7. **v-html usage** — even with sanitization, human verifies context.
8. **Store schema changes** — state shape affects all consumers.

The agent creates a Draft PR with these items highlighted in the
description. The human reviewer checks the highlighted items and
approves or requests changes. No auto-merge for these categories.

---

## Sources

- [Vue 3 Composition API FAQ](https://vuejs.org/guide/extras/composition-api-faq.html)
- [Vue 3 Security Best Practices](https://vuejs.org/guide/best-practices/security)
- [Vue 3 Testing Guide](https://vuejs.org/guide/scaling-up/testing)
- [Vite 6 Build Optimization Guide](https://markaicode.com/vite-6-build-optimization-guide/)
- [Vite Build Options Documentation](https://vite.dev/config/build-options)
- [Vite Performance Guide](https://vite.dev/guide/performance)
- [Pinia Defining a Store](https://pinia.vuejs.org/core-concepts/)
- [Pinia Vue Best Practices (Sean Wilson)](https://seanwilson.ca/blog/pinia-vue-best-practices.html)
- [Vue 3 Testing Pyramid with Vitest Browser Mode](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/)
- [Testing Vue Composables Lifecycle (Dylan Britz)](https://dylanbritz.dev/writing/testing-vue-composables-lifecycle/)
- [Playwright E2E Best Practices (BrowserStack)](https://www.browserstack.com/guide/playwright-best-practices)
- [Playwright Vue Testing Guide (BrowserStack)](https://www.browserstack.com/guide/playwright-vue)
- [OWASP Top 10 for Vue.js (Charles Jones)](https://charlesjones.dev/blog/owasp-top-10-vuejs-security)
- [Vue.js 3 Security Practices (Borstch)](https://borstch.com/blog/development/vuejs-3-security-practices-safeguarding-your-application)

---

*Savia Model 01 v1.0 — 2026-04-02 | Exemplar: savia-web*
