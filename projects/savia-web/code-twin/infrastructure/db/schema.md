---
module_id: DbSchema
layer: infrastructure
version: "1.0.0"
last_sync: "2026-06-06T10:00:00Z"
token_budget: 330
stale_after_days: 30
depends_on: []
provides:
  - users
  - projects
  - tasks
status: STABLE
---
# DB Schema — savia-web

Represents the server-side data model surfaced via the API.
Client uses localStorage only for UI preferences (`savia:backlog:*` keys).

## Table: users

| column | type | nullable |
|--------|------|----------|
| id | uuid | false |
| username | varchar | false |
| display_name | varchar | false |
| role | varchar | false |
| created_at | timestamp | false |
| last_active | timestamp | true |

## Table: projects

| column | type | nullable |
|--------|------|----------|
| id | uuid | false |
| slug | varchar | false |
| name | varchar | false |
| owner_id | uuid | false |
| created_at | timestamp | false |
| archived | boolean | false |

## Table: tasks

| column | type | nullable |
|--------|------|----------|
| id | uuid | false |
| project_id | uuid | false |
| title | varchar | false |
| state | varchar | false |
| created_at | timestamp | false |
| assignee_id | uuid | true |
