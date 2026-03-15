---
id: "phase2.5-project-context-switch"
title: "Project Context Switch — Refresh All Pages on Project Change"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# Project Context Switch

## Objetivo

When the user changes the selected project in the TopBar dropdown, ALL page data must refresh to reflect the new project context. Currently only the backlog page watches for project changes.

## Requisitos Funcionales

### RF-01: Stores that Must React to Project Change

| Store | Endpoint | Action |
|-------|----------|--------|
| backlog | `/backlog?project={id}` | Reload PBIs/tasks |
| dashboard | `/dashboard?project={id}` | Reload KPIs, tasks |
| pipeline | `/pipelines?project={id}` | Reload pipeline runs |
| integrations | `/integrations?project={id}` | Reload workflows |
| reports | `/reports/*?project={id}` | Reload all report data |

### RF-02: Implementation Pattern

- Each store watches `projectStore.selectedId`
- On change: clear current data + reload from Bridge
- Show loading spinner during reload
- Pass `project={id}` query param to all Bridge requests

### RF-03: Reports Store

- The `useReportData` composable must include project context
- All 7 report sub-pages refresh when project changes
- Chart data updates without page navigation

## Criterios de Aceptacion

- [ ] Changing project while on /backlog refreshes backlog
- [ ] Changing project while on / refreshes dashboard
- [ ] Changing project while on /reports/* refreshes report charts
- [ ] Changing project while on /pipelines refreshes pipeline list
- [ ] Loading spinner shows during data refresh
- [ ] No stale data from previous project visible
