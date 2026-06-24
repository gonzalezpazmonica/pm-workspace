---
module_id: item-queries
layer: application
version: "1.0.0"
last_sync: "2026-06-23T07:37:07Z"
token_budget: 250
stale_after_days: 3650  # SE-191 fix: avoid temporal aging of fixture
depends_on:
  - ItemRepository
provides:
  - GetItemByIdQuery
  - ListItemsQuery
status: STABLE
---
# Item Queries — fixture-project

## GetItemByIdQuery

**Input**: `{ record_id: uuid }`
**Returns**: `ItemDto | null`
**Caching**: 5 min TTL, invalidated on ItemArchived event

## ListItemsQuery

**Input**: `{ state?: ItemState, page?: int, limit?: int }`
**Returns**: `{ items: ItemDto[], total: int }`
**Defaults**: page=1, limit=20
**Sorting**: by title ASC
