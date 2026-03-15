# Spec: Savia Web — Pipeline Management

## Metadatos
- project: savia-web
- phase: 2 — Savia Web Core
- feature: pipelines
- status: pending
- developer_type: human
- depends: savia-web-mvp (Bridge connection)
- parent_pbi: ""

## Objective

Visual dashboard for CI/CD pipelines, allowing PMs and QA to see build status, logs, and trigger runs without terminal access. Connects to the local pipeline engine (Era 110) as primary source, with optional Azure Pipelines and GitHub Actions as secondary.

## Architecture

### Route: `/pipelines`

### Data sources (priority order)

1. **Local pipeline engine** — `scripts/pipeline-local.sh` (Era 110). Reads `pipeline.yaml` from project root.
2. **Azure Pipelines** — via Bridge proxy to Azure DevOps REST API (if configured).
3. **GitHub Actions** — via Bridge proxy to GitHub API (if configured).

Bridge detects available sources from project's `CLAUDE.md` config.

```
GET /pipelines                     → PipelineSummary[]
GET /pipelines/{id}                → PipelineDetail (stages, steps, logs)
GET /pipelines/{id}/runs           → PipelineRun[] (history)
GET /pipelines/{id}/runs/{runId}   → RunDetail (stages, logs, artifacts)
POST /pipelines/{id}/run           → Trigger new run
```

## Functional Requirements

### FR-01: Pipeline List

Table showing all configured pipelines:

| Column | Description |
|--------|-------------|
| Name | Pipeline name from YAML definition |
| Source | Local / Azure Pipelines / GitHub Actions (icon) |
| Last run | Timestamp + duration |
| Status | Success / Failed / Running / Never run (color badge) |
| Branch | Branch of last run |
| Trigger | Manual button |

### FR-02: Pipeline Detail

Click on pipeline → detail page with:

**Run History**: table of last 20 runs with status, branch, duration, @trigger_by.

**Stage Visualization**: horizontal flow diagram showing stages (e.g., Build → Test → Deploy). Each stage shows status (green/red/grey/spinning). Click stage → shows step logs.

**Logs Viewer**: monospace text area with auto-scroll. Syntax highlighting for errors (red) and warnings (amber). Search within logs. Download full log button.

### FR-03: Trigger Run

Button "Run Pipeline" → modal with:
- Branch selector (dropdown, default: current branch)
- Variables override (optional key-value pairs)
- Confirm button

Shows progress in real-time via SSE from Bridge.

### FR-04: Artifacts

If a run produces artifacts (build outputs, test reports, coverage):
- List with name, size, download link
- Coverage report inline if HTML format

## Non-Functional Requirements

- NFR-01: All `.vue` files <= 150 lines
- NFR-02: Log viewer handles 10,000+ lines without lag (virtual scroll)
- NFR-03: Stage diagram renders with CSS (no canvas/SVG library dependency)
- NFR-04: Running pipelines show live status (SSE or polling every 5s)
- NFR-05: Zero vendor lock-in — works with local engine without any cloud service

## Vue Components (estimated)

```
src/pages/PipelinesPage.vue
src/pages/PipelineDetailPage.vue
src/components/pipelines/
  PipelineList.vue
  PipelineRow.vue
  StageFlow.vue
  StepLogs.vue
  RunHistoryTable.vue
  TriggerModal.vue
  ArtifactList.vue
src/stores/pipelines.ts
src/composables/usePipelines.ts
src/types/pipelines.ts
```

## Acceptance Criteria

- [ ] AC-1: Pipeline list shows all pipelines with last run status
- [ ] AC-2: Clicking a pipeline shows run history and stage diagram
- [ ] AC-3: Stage diagram updates in real-time for running pipelines
- [ ] AC-4: Log viewer shows step output with error highlighting
- [ ] AC-5: "Run Pipeline" triggers execution and shows live progress
- [ ] AC-6: Works with local pipeline engine alone (no cloud dependency)
- [ ] AC-7: PM can see if tests passed without understanding terminal output
