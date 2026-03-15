---
id: "phase2.5-backlog-filters"
title: "Backlog Filters — Type, State, Person"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# Backlog Filters

## Objetivo

Add Azure DevOps-style filters to the backlog tree and kanban views. Users can show/hide item types (Spec, PBI, Task), filter by state, and filter by assigned person.

## Requisitos Funcionales

### RF-01: Type Filter

- Toggle buttons: Spec | PBI | Task (all ON by default)
- Clicking a type button hides/shows that level in the tree
- In kanban view, type filter applies to PBI cards

### RF-02: State Filter

- Multi-select dropdown with states: New, Active, Resolved, Closed, Done, Draft
- Default: all states visible
- Applied across all levels (specs, PBIs, tasks)

### RF-03: Person Filter

- Dropdown with all unique `assigned_to` values from loaded data
- Options: "All", "@alice", "@bob", etc.
- "Mine" shortcut shows only items assigned to current user
- Filter applies to PBIs and tasks (specs show if any child matches)

### RF-04: Filter Bar UI

- Horizontal bar below backlog toolbar, above tree/kanban
- Compact: type toggles + state dropdown + person dropdown
- Active filter count badge on filter bar

## Criterios de Aceptacion

- [ ] Type toggles show/hide corresponding rows in tree
- [ ] State filter reduces visible items to selected states
- [ ] Person filter shows only items assigned to selected person
- [ ] Filters persist in localStorage (see persistence spec)
- [ ] Combined filters work (type AND state AND person)
- [ ] Filter badge shows count of active filters
- [ ] Kanban view respects all filters
