---
module_id: domain-entities
layer: domain
version: "1.0.0"
last_sync: "2026-06-01T14:30:00Z"
token_budget: 350
stale_after_days: 30
depends_on: []
provides:
  - Item
  - Category
status: STABLE
---
# Domain Entities — fixture-project

## Item

**Fields**: `record_id: uuid`, `title: string`, `state: ItemState`
**Invariants**: `title` max 200 chars; `state` transitions: draft→active→archived (no reverse)
**Factory**: `Item.create(title)` sets state=draft, validates title ≠ blank
**Identity**: equality by `record_id`

## Category

**Fields**: `category_id: uuid`, `label: string`, `parent_id: uuid | null`
**Invariants**: `label` max 100 chars, unique per parent; max nesting depth 3
**Identity**: equality by `category_id`
