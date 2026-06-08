---
module_id: ItemRepository
layer: infrastructure
version: "1.0.0"
last_sync: "2026-06-08T14:30:00Z"
token_budget: 380
stale_after_days: 14
depends_on:
  - domain-entities
provides:
  - findById
  - findAll
  - save
  - delete
status: STABLE
---
# ItemRepository — fixture-project

## findById(record_id: uuid): Item | null

**Query**: `SELECT * FROM items WHERE record_id = $1 LIMIT 1`
**Returns**: Item entity or null
**Side effects**: none

## findAll(filter: { state?: ItemState }): Item[]

**Query**: `SELECT * FROM items WHERE ($1::text IS NULL OR state = $1)`
**Returns**: matching Item rows; empty list if none

## save(item: Item): void

**Write**: `INSERT INTO items ... ON CONFLICT (record_id) DO UPDATE SET ...`
**Side effects**: DB WRITE items table

## delete(record_id: uuid): void

**Write**: `DELETE FROM items WHERE record_id = $1`
**Side effects**: DB WRITE items table
**Edge cases**: no-op if record_id not found (0 rows affected, no error)
