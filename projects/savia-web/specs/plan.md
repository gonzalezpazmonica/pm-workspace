# Savia Web MVP — Implementation Plan (Retroactive)

## Overview

Documents the build phases of savia-web, a Vue 3 + TypeScript web client
for PM-Workspace that connects to Savia Bridge (Python HTTPS server).

---

## Phase 1: Bridge Report Endpoints

**Scope**: Python module `scripts/savia_bridge_reports.py` with 8 report functions.
**Bridge routing**: `GET /reports/{name}?project=X` dispatched in `savia-bridge.py`.

| Function | Endpoint | Response Type |
|---|---|---|
| `velocity()` | `/reports/velocity` | `ReportResponse<VelocityData>` |
| `burndown()` | `/reports/burndown` | `ReportResponse<BurndownData>` |
| `dora()` | `/reports/dora` | `ReportResponse<DoraData>` |
| `team_workload()` | `/reports/team-workload` | `ReportResponse<TeamWorkloadData>` |
| `quality()` | `/reports/quality` | `ReportResponse<QualityData>` |
| `debt()` | `/reports/debt` | `ReportResponse<DebtData>` |
| `cycle_time()` | `/reports/cycle-time` | `ReportResponse<CycleTimeData>` |
| `portfolio()` | `/reports/portfolio` | `ReportResponse<PortfolioData>` |

All return mock/calculated data with `random.seed(42)` for determinism.

## Phase 2: Vue Scaffolding

**Scope**: Project init with Vite 6 + Vue 3 + TypeScript.

- `npm create vite@latest` with vue-ts template
- Added dependencies: `vue-router`, `pinia`, `echarts`, `vue-echarts`, `marked`, `highlight.js`
- Configured `vite.config.ts` (dev port 5173, build output)
- Created `CLAUDE.md` with stack, architecture, design system, rules

## Phase 3: Layout and Common Components

**Scope**: Shell UI — sidebar navigation, top bar, shared components.

| Component | Path | Purpose |
|---|---|---|
| MainLayout | `layouts/MainLayout.vue` | Sidebar + topbar + router-view |
| AppSidebar | `components/AppSidebar.vue` | Navigation links for all 10 pages |
| AppTopBar | `components/AppTopBar.vue` | Connection status, dark mode toggle |
| LoadingSpinner | `components/LoadingSpinner.vue` | Reusable loading indicator |
| EmptyState | `components/EmptyState.vue` | Empty data placeholder |
| ProjectSelector | `components/ProjectSelector.vue` | Dropdown for project switching |

Styles: `variables.css` (Savia palette: `#6B4C9A`, `#CDB4DB`, dark mode),
`global.css` (reset, typography, utility classes).

## Phase 4: Core Pages

**Scope**: 10 route-level pages with Bridge data fetching.

| Page | Route | Key Features |
|---|---|---|
| HomePage | `/` | Dashboard cards, sprint summary, task list |
| ChatPage | `/chat` | SSE streaming, markdown rendering, permission dialogs |
| CommandsPage | `/commands` | Grouped command families, search/filter |
| KanbanPage | `/kanban` | Column-based board, drag-and-drop cards |
| ApprovalsPage | `/approvals` | Pending items list, approve/reject actions |
| TimeLogPage | `/timelog` | Hour entry form, daily entries table |
| FileBrowserPage | `/files` | Directory tree, text file viewer |
| ProfilePage | `/profile` | User info, stats cards |
| SettingsPage | `/settings` | Bridge config form, connection test |
| ReportsLayout | `/reports` | Tab navigation for 7 sub-reports |

Supporting infrastructure:
- `composables/useBridge.ts` — Generic `get<T>()` / `post<T>()` with auth headers
- `composables/useSSE.ts` — SSE stream reader with event parsing
- `stores/auth.ts` — Connection settings (localStorage persistence)
- `stores/dashboard.ts` — Dashboard data + loading state
- `stores/chat.ts` — Message history, streaming state, permissions
- `stores/reports.ts` — Active tab + selected project

## Phase 5: Report Pages and ECharts Components

**Scope**: 7 report sub-pages + 10 chart wrapper components.

| Chart Component | Type | Used By |
|---|---|---|
| VelocityChart | Grouped bar | SprintReportPage |
| BurndownChart | Dual line (ideal vs actual) | SprintReportPage |
| SpDistribution | Pie chart | SprintReportPage |
| CycleTimeChart | Dual line (cycle vs lead) | BoardFlowPage |
| WorkloadHeatmap | Bar chart (capacity vs assigned) | TeamWorkloadPage |
| PortfolioRadar | Radar chart (multi-axis) | PortfolioPage |
| DoraGauges | 4 gauge cards | DoraMetricsPage |
| CoverageGauge | Gauge chart | QualityPage |
| BugSeverityPie | Pie chart | QualityPage |
| DebtTrendLine | Area line chart | DebtPage |

Each chart component: single file, <= 150 lines, `defineProps<{data: T}>()`.

## Phase 6: Integration and Build Verification

**Scope**: Type alignment, build fixes, production setup.

- Type definitions aligned: `types/bridge.ts`, `types/reports.ts`, `types/chat.ts`
- Fixed TypeScript strict mode errors across all components
- Verified `npm run build` produces clean output
- Created `scripts/setup-savia-web.sh` (build + serve on port 8081)
- Router configured with lazy-loaded routes for all pages

## Phase 7: Tests, Documentation, CHANGELOG (Pending)

**Scope**: Not yet implemented.

- [ ] Unit tests for composables (`useBridge`, `useSSE`)
- [ ] Component tests for chart wrappers (render with mock data)
- [ ] E2E test: Settings -> Connect -> Chat flow
- [ ] CHANGELOG entry for savia-web MVP
- [ ] Update root README with savia-web section

---

## File Count Summary

| Category | Count |
|---|---|
| Pages | 10 + 7 report sub-pages |
| Components | 10 charts + 4 common + sidebar + topbar |
| Stores | 4 (auth, dashboard, chat, reports) |
| Composables | 2 (useBridge, useSSE) |
| Type definitions | 3 files, 20 interfaces |
| Styles | 2 (variables.css, global.css) |
| Layouts | 1 (MainLayout) |
| **Total Vue/TS files** | **~40** |
