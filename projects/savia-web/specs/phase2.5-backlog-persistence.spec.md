---
id: "phase2.5-backlog-persistence"
title: "Backlog View State Persistence"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# Backlog View State Persistence

## Objetivo

Persist backlog UI state in localStorage so that refreshing (F5) restores the exact same view: filters, view mode (tree/kanban), expanded tree nodes, selected item, and scroll position.

## Requisitos Funcionales

### RF-01: Persisted State

| State | Storage Key | Default |
|-------|------------|---------|
| View mode (tree/kanban) | `savia:backlog:viewMode` | `tree` |
| Expanded items (Set of IDs) | `savia:backlog:expanded` | all specs |
| Active filters (type, state, person) | `savia:backlog:filters` | all visible |
| Selected item ID + type | `savia:backlog:selected` | null |
| Selected project | `savia:selectedProject` | `_workspace` |

### RF-02: Save Triggers

- Save on every user interaction (toggle, filter, select, expand)
- Debounce writes: max 1 write per 500ms

### RF-03: Restore on Load

- On BacklogPage mount, read persisted state before fetching data
- Apply filters and expansion state after data loads
- If persisted item no longer exists, clear selection

## Criterios de Aceptacion

- [ ] Switching view mode persists across page refresh
- [ ] Expanding/collapsing tree nodes persists
- [ ] Filters persist across refresh
- [ ] Selected item re-selects after refresh (if still exists)
- [ ] Project selector persists (already implemented)
