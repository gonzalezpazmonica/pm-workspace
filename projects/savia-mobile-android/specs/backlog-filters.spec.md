---
id: "mobile-backlog-filters"
title: "Backlog Filters — Type, State, Person"
status: "approved"
developer_type: "human"
parent_pbi: ""
---

# Backlog Filters (Mobile)

## Objetivo

Azure DevOps-style filters for the mobile backlog screen. Filter by item type (Spec/PBI/Task), state, and assigned person.

## Requisitos

- Chip-based filter bar at top of backlog screen
- Type chips: Spec | PBI | Task (toggle on/off)
- State filter: bottom sheet with multiselect checkboxes
- Person filter: bottom sheet with team members + "Mine" shortcut
- Persist filter state in SharedPreferences
- Combined filters (AND logic)
- Filter count badge on filter icon
- Filters apply to both tree and kanban views
