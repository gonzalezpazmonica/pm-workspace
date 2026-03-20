# Spec: Savia Web — Global Project Selector

## Metadatos
- project: savia-web
- phase: 2 — Savia Web Core
- feature: project-selector-global
- status: pending
- developer_type: human
- depends: savia-web-mvp

## Objective

Add a persistent project selector dropdown in the TopBar so the user can switch between projects at any time. Every project folder under `projects/` is a selectable project, **plus Savia itself** (the root workspace). The selected project determines the context for backlog, pipelines, files, reports, and all project-scoped views.

## Current State

- `ProjectSelector.vue` exists but is only used inside `HomePage.vue` as part of the dashboard.
- `dashboard.selectProject(id)` stores selection in the dashboard store only.
- No global project context — each page fetches data independently.

## Design

### TopBar integration

The project selector goes in the TopBar, between the hamburger menu and the spacer:

```
[☰] [▾ savia-web     ] ·················· Connected · @monica [Logout]
      ├─ Savia (workspace)
      ├─ savia-web
      ├─ dotnet-microservices-home-lab
      ├─ proyecto-alpha
      └─ pm-workspace-devops
```

Dropdown styled consistently with the existing `ProjectSelector.vue` but enhanced:
- Project name + health indicator (colored dot: green/amber/red/grey)
- "Savia (workspace)" always first — represents the root `~/savia/` folder
- Separator line after Savia, then alphabetical project list
- Current selection persisted in localStorage (`savia-web:selectedProject`)
- On change: emits event, all project-scoped stores reload

### Savia as a project

When "Savia (workspace)" is selected:
- Backlog → shows items from `backlog/` at root level (if any, or empty state)
- Files → navigates from root `~/savia/`
- Pipelines → shows pipeline.yaml from root
- Reports → shows workspace-level metrics

When a project is selected (e.g., "savia-web"):
- Backlog → shows `projects/savia-web/backlog/`
- Files → navigates from `projects/savia-web/`
- Pipelines → shows project-specific pipelines
- Reports → shows project-specific metrics

## Data Model

### Bridge API

```
GET /projects → ProjectInfo[]
```

Response:
```json
[
  {
    "id": "_workspace",
    "name": "Savia (workspace)",
    "path": ".",
    "hasClaude": true,
    "hasBacklog": false,
    "health": "healthy"
  },
  {
    "id": "savia-web",
    "name": "savia-web",
    "path": "projects/savia-web",
    "hasClaude": true,
    "hasBacklog": true,
    "health": "healthy"
  }
]
```

Bridge implementation: scan `projects/*/CLAUDE.md` to discover projects. Always include `_workspace` as first entry.

### New Pinia store: `project.ts`

```typescript
export const useProjectStore = defineStore('project', () => {
  const projects = ref<ProjectInfo[]>([])
  const selectedId = ref<string>(
    localStorage.getItem('savia:selectedProject') || '_workspace'
  )
  const selected = computed(() =>
    projects.value.find(p => p.id === selectedId.value)
  )

  function select(id: string) {
    selectedId.value = id
    localStorage.setItem('savia:selectedProject', id)
    // Emit global event for other stores to reload
  }

  async function load() { /* GET /projects */ }

  return { projects, selectedId, selected, select, load }
})
```

### Type addition in `types/bridge.ts`

```typescript
export interface ProjectInfo {
  id: string
  name: string
  path: string
  hasClaude: boolean
  hasBacklog: boolean
  health: 'healthy' | 'warning' | 'critical' | 'unknown'
}
```

## Implementation

### 1. Refactor `ProjectSelector.vue`

- Move from dashboard-only to global (reads from `projectStore` not `dashboardStore`)
- Add health dot indicator per project
- Add "Savia (workspace)" as first option with separator
- Style as TopBar-integrated dropdown (not standalone select)

### 2. Update `AppTopBar.vue`

Insert `<ProjectSelector />` after the menu button.

### 3. Create `stores/project.ts`

Global project state. On `select()`, triggers reload of all project-scoped stores.

### 4. Update project-scoped pages

Pages that need to react to project change:
- `HomePage.vue` → reload dashboard for selected project
- `KanbanPage.vue` / future `BacklogPage.vue` → reload backlog
- `FileBrowserPage.vue` → reset to project root
- `TimeLogPage.vue` → filter by project
- Reports pages → pass project to API calls

Each page watches `projectStore.selectedId` and reloads on change.

### 5. Bridge: `GET /projects` endpoint

Scans `projects/` directory. For each subfolder with `CLAUDE.md`, returns `ProjectInfo`. Always includes `_workspace` pointing to root.

## Acceptance Criteria

- [ ] AC-1: TopBar shows project dropdown between menu button and spacer
- [ ] AC-2: Dropdown lists "Savia (workspace)" first, then all `projects/*/` alphabetically
- [ ] AC-3: Each project shows health indicator dot (green/amber/red/grey)
- [ ] AC-4: Selecting a project persists to localStorage and survives page reload
- [ ] AC-5: Switching project reloads backlog, files, reports for the new context
- [ ] AC-6: "Savia (workspace)" shows root-level data (files from `~/savia/`)
- [ ] AC-7: "savia-web" shows project-level data (files from `projects/savia-web/`)
- [ ] AC-8: New projects added to `projects/` appear in dropdown on next load
