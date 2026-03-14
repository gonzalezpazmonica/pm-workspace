# Spec: Savia Web MVP — Vue.js Client for PM-Workspace

## Metadatos
- project: savia-web
- developer_type: human
- status: implemented (retroactive spec)
- stack: Vue 3 + TypeScript + Vite 6 + Pinia + ECharts 5

## Objective

Provide a browser-based dashboard for PM-Workspace, connecting to Savia Bridge
(Python HTTPS server) for data and Claude Code CLI interaction via SSE streaming.

## Architecture Decisions

- **Vue 3 Composition API** with `<script setup>` for all components
- **Pinia** for state (4 stores: auth, dashboard, chat, reports)
- **Custom CSS only** (no framework) with Savia violet palette (`#6B4C9A`)
- **ECharts 5 + vue-echarts 7** for 10 chart wrapper components
- **SSE streaming** for real-time chat with Claude (not WebSocket)
- **localStorage** for Bridge connection settings (host, port, token, TLS)

## Functional Requirements

### FR-01: Home Dashboard (`/`)
Display greeting, project list, sprint summary, personal tasks, blocked items count.
Data source: `GET /dashboard` -> `DashboardData`.

### FR-02: Chat with Claude (`/chat`)
SSE-streamed conversation. Supports `text`, `tool_use`, `permission_request` events.
User can approve/deny tool permissions inline. `POST /chat` + `POST /chat/permission`.

### FR-03: Command Explorer (`/commands`)
Browse slash commands grouped by family. Each shows name, description, usage.
Data source: `GET /commands` -> `CommandFamily[]`.

### FR-04: Kanban Board (`/kanban`)
Drag-and-drop board with columns by state. Cards show type, assignee, priority.
Data source: `GET /board` -> `BoardColumn[]`.

### FR-05: Approvals Queue (`/approvals`)
List pending approval requests (PRs, specs). Approve/reject actions.
Data source: `GET /approvals` -> `ApprovalRequest[]`.

### FR-06: Time Log (`/timelog`)
Log hours against tasks. View entries by date. Data: `GET/POST /timelog`.

### FR-07: File Browser (`/files`)
Navigate workspace directories and view text files. `GET /files?path=X`.

### FR-08: Profile (`/profile`)
View user profile and stats. Data: `GET /profile` -> `UserProfile`.

### FR-09: Settings (`/settings`)
Configure Bridge connection: host, port, token, TLS toggle. Health check button.
Persisted to localStorage via `authStore.save()`.

### FR-11: Connection Wizard (auto on startup)
On first load or when Bridge is unreachable, a modal overlay guides the user:
1. **Auto-detect**: tries `localhost:8922` with current saved settings.
2. **Manual form**: if auto-detect fails, shows host/port/password/TLS fields.
3. **Login**: if password provided, `POST /auth/login` to obtain Bearer token.
4. **Success**: overlay dismisses automatically when connected.
Displayed by `ConnectionWizard.vue` in `MainLayout` when `auth.connected === false`.

### FR-10: Reports Dashboard (`/reports/*`)
7 sub-pages with ECharts visualizations, project selector, tabbed navigation.

| Sub-page | Route | Chart Component | Bridge Endpoint |
|---|---|---|---|
| Sprint | `/reports/sprint` | VelocityChart, BurndownChart, SpDistribution | `/reports/velocity`, `/reports/burndown` |
| Board Flow | `/reports/board-flow` | CycleTimeChart | `/reports/cycle-time` |
| Team Workload | `/reports/team-workload` | WorkloadHeatmap | `/reports/team-workload` |
| Portfolio | `/reports/portfolio` | PortfolioRadar | `/reports/portfolio` |
| DORA Metrics | `/reports/dora` | DoraGauges | `/reports/dora` |
| Quality | `/reports/quality` | CoverageGauge, BugSeverityPie | `/reports/quality` |
| Tech Debt | `/reports/debt` | DebtTrendLine | `/reports/debt` |

## Bridge API Contract

All endpoints prefixed with Bridge base URL (default `https://localhost:8922`).
Auth: `Authorization: Bearer {token}` header. Response: JSON.

| Method | Path | Auth | Response Type |
|---|---|---|---|
| GET | `/dashboard` | Yes | `DashboardData` |
| POST | `/chat` | Yes | SSE stream (`StreamEvent`) |
| POST | `/chat/permission` | Yes | `{ok: boolean}` |
| GET | `/commands` | Yes | `CommandFamily[]` |
| GET | `/board` | Yes | `BoardColumn[]` |
| GET | `/approvals` | Yes | `ApprovalRequest[]` |
| GET/POST | `/timelog` | Yes | `TimeEntry[]` |
| GET | `/files?path=X` | Yes | `FileEntry[]` |
| GET | `/profile` | No | `UserProfile` |
| GET | `/reports/{name}?project=X` | Yes | `ReportResponse<T>` |

## Non-Functional Requirements

- **NFR-01**: All `.vue` files <= 150 lines
- **NFR-02**: Dark/light mode toggle via `[data-theme]` attribute, persisted in localStorage
- **NFR-03**: Responsive layout (sidebar collapses on mobile)
- **NFR-04**: No external CSS frameworks; custom CSS with design tokens
- **NFR-05**: Types mirror Bridge/Kotlin domain models exactly
- **NFR-06**: All software libre — zero vendor lock-in (ISC, MIT, SIL OFL licenses)
- **NFR-07**: Lucide icons (ISC license) for all UI icons — no emoji icons
- **NFR-08**: Savia owl SVG logo (from savia-mobile-android) in sidebar, login, favicon
- **NFR-09**: Subtle glassmorphism: `backdrop-filter: blur`, semi-transparent surfaces
- **NFR-10**: Inter font (SIL Open Font License) via Google Fonts CDN
- **NFR-11**: Sidebar footer shows "Savia Web v{version}" and dark/light toggle
- **NFR-12**: Accessibility: `:focus-visible` rings, contrast ratios, semantic HTML
- **NFR-13**: TopBar shows "Connected · {userName}" + Logout when authenticated

## Key Acceptance Criteria

**Given** Bridge is not reachable on startup,
**When** the app loads,
**Then** a Connection Wizard overlay appears, auto-detects, and shows a manual form if auto-detect fails.

**Given** user fills the wizard form with valid host/port/password,
**When** user clicks "Connect",
**Then** the wizard authenticates via `POST /auth/login`, saves the token, and dismisses.

**Given** Bridge is running on configured host:port,
**When** user opens Settings and clicks "Test Connection",
**Then** health check calls `GET /dashboard` and shows connected/disconnected status.

**Given** user is on Chat page,
**When** user sends a message,
**Then** SSE stream opens via `POST /chat` and tokens render incrementally.

**Given** a `permission_request` event arrives during chat,
**When** user clicks "Allow" or "Deny",
**Then** `POST /chat/permission` sends the decision and streaming continues.

**Given** user clicks the dark/light toggle in the sidebar,
**When** the theme changes,
**Then** `[data-theme]` updates on `<html>`, all surfaces/text/icons adapt, and the choice persists in localStorage.

**Given** user navigates to Reports > DORA,
**When** page loads,
**Then** `GET /reports/dora?project=X` is called and 4 gauge charts render.

## File Inventory

- 4 stores: `auth.ts`, `dashboard.ts`, `chat.ts`, `reports.ts`
- 2 composables: `useBridge.ts`, `useSSE.ts`
- 3 type files: `bridge.ts`, `reports.ts`, `chat.ts`
- 10 pages + 7 report sub-pages + 1 report layout
- 10 chart components + 6 common components (LoginPage, RegisterWizard, AppSidebar, AppTopBar, EmptyState, LoadingSpinner)
- 1 layout (`MainLayout.vue`) + sidebar + topbar + login overlay
- 2 style files + Savia logo SVG + favicon SVG
- 2 style files: `variables.css`, `global.css`
