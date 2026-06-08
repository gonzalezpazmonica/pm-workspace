---
module_id: ItemListComponent
layer: frontend
version: "1.0.0"
last_sync: "2026-06-08T14:30:00Z"
token_budget: 320
stale_after_days: 14
depends_on:
  - api-routes
provides:
  - ItemListComponent
status: STABLE
---
# ItemListComponent — fixture-project

Displays a paginated, filterable list of items. Standalone component.

## Props

| prop | type | required | default |
|------|------|----------|---------|
| initialState | ItemState | no | undefined (all) |
| pageSize | number | no | 20 |

## State

| key | type | description |
|-----|------|-------------|
| items | ItemDto[] | current page results |
| total | number | total matching items |
| page | number | current page (1-indexed) |
| loading | boolean | true while fetch in flight |
| error | string \| null | last error message |

## Behaviour

- On mount: calls `GET /items?state={initialState}&page=1&limit={pageSize}`
- On page change: re-fetches with new `page`
- On filter change: resets to page=1, re-fetches
- Empty state: renders `<EmptyState message="No items found" />`
- Loading state: renders `<Spinner />`
- Error state: renders `<ErrorBanner message={error} />`
