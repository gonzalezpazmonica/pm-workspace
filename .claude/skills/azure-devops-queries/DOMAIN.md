# Azure DevOps Queries — Domain Context

## Why this skill exists

Azure DevOps stores all project truth: work items (PBIs, Tasks, Bugs), sprints, capacity, custom fields. Without query capability, PMs are blind to status. This skill provides a query language (WIQL) to ask any question about project state: "What's blocking us?" "Who's overloaded?" "What shipped last week?"

## Domain concepts

- **WIQL (Work Item Query Language)** — SQL-like syntax for querying work items (SELECT, WHERE, ORDER BY)
- **Work Item** — PBI | Bug | Task | Epic | Feature; has ID, state, assigned, story points, tags, custom fields
- **Iteration** — Sprint; has dates, team, capacity
- **Area Path** — Product area (e.g., "API" vs "Frontend"); organizes backlog
- **Query Saved vs Ad-hoc** — Saved queries reusable; ad-hoc queries one-time analysis

## Business rules it implements

- **RN-QUERY-01**: Queries must be parameterized (project, team, sprint) for reusability
- **RN-QUERY-02**: WIQL results cached when possible (API rate limiting)
- **RN-QUERY-03**: Queries used in dashboards/reports must show source for auditability

## Relationship to other skills

**Upstream:** None (source of truth)
**Downstream:** All commands depend on this skill to fetch data (sprint-status, board-flow, capacity-planning, reporting)
**Parallel:** `azure-pipelines` reads same work items for automation

## Key decisions

- **WIQL patterns library** — Pre-built queries for common questions (blockers, overdue, unestimated). Copy/paste > learn WIQL syntax.
- **Caching strategy** — Cache query results 5-10 min (fresh enough for sprints, cheap on API quota)
- **Real-time fallback** — If cache stale, fetch live; don't show stale data in dashboards
