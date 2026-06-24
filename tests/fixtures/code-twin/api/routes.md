---
module_id: api-routes
layer: api
version: "1.0.0"
last_sync: "2026-06-23T07:37:07Z"
token_budget: 450
stale_after_days: 3650  # SE-191 fix: avoid temporal aging of fixture
depends_on:
  - item-use-cases
  - item-queries
provides:
  - POST /items
  - GET /items
  - GET /items/:id
  - DELETE /items/:id
status: STABLE
---
# API Routes — fixture-project

## POST /items

**Auth**: Bearer token required (role: user)
**Body**: `{ title: string }`
**Calls**: `CreateItemUseCase`
**Returns**: `201 { record_id, title, state }` | `400 VALIDATION_ERROR` | `401 UNAUTHORIZED`

## GET /items

**Auth**: Bearer token required
**Query params**: `state?: ItemState`, `page?: int (default 1)`, `limit?: int (default 20)`
**Calls**: `ListItemsQuery`
**Returns**: `200 { items: ItemDto[], total: int }` | `401 UNAUTHORIZED`

## GET /items/:id

**Auth**: Bearer token required
**Calls**: `GetItemByIdQuery`
**Returns**: `200 ItemDto` | `404 NOT_FOUND` | `401 UNAUTHORIZED`

## DELETE /items/:id

**Auth**: Bearer token required (role: admin)
**Calls**: `ArchiveItemUseCase`
**Returns**: `204 No Content` | `404 NOT_FOUND` | `403 FORBIDDEN` | `422 INVALID_STATE`
