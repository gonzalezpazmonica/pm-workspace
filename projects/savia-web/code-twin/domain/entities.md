---
module_id: DomainEntities
layer: domain
version: "1.0.0"
last_sync: "2026-06-06T10:00:00Z"
token_budget: 380
stale_after_days: 30
depends_on: []
provides:
  - SpecItem
  - PbiItem
  - TaskItem
  - BacklogFilters
status: STABLE
---
# Domain Entities — savia-web

## SpecItem

**Fields**: `id: string`, `title: string`, `state: string`, `assigned_to: string`, `pbis: PbiItem[]`
**Invariants**: `pbis` is always an array (never null); `id` matches Azure DevOps work item id
**Identity**: equality by `id`

## PbiItem

**Fields**: `id: string`, `title: string`, `state: string`, `type: string`, `priority: string`, `assigned_to: string`, `estimated_hours: number`, `tasks: TaskItem[]`
**Invariants**: `estimated_hours ≥ 0`; `tasks` is always an array
**Identity**: equality by `id`

## TaskItem

**Fields**: `id: string`, `title: string`, `state: string`, `type: string`, `assigned_to: string`, `estimated_hours: number`, `remaining_hours: number`
**Invariants**: `remaining_hours ≤ estimated_hours`; both ≥ 0
**Identity**: equality by `id`

## BacklogFilters

**Fields**: `showSpecs: boolean`, `showPbis: boolean`, `showTasks: boolean`, `states: string[]`, `assignee: string`
**Notes**: `assignee = ''` means all; `'@handle'` filters to specific user; persisted in localStorage via `savia:backlog:` prefix
