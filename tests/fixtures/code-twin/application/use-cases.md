---
module_id: item-use-cases
layer: application
version: "1.0.0"
last_sync: "2026-06-08T14:30:00Z"
token_budget: 420
stale_after_days: 14
depends_on:
  - ItemRepository
  - domain-entities
provides:
  - CreateItemUseCase
  - ArchiveItemUseCase
status: STABLE
---
# Item Use Cases — fixture-project

## CreateItemUseCase

**Input**: `CreateItemCommand { title: string }`
**Logic**:
1. Validate title ≠ blank, max 200 chars → THROW 400 VALIDATION_ERROR
2. `Item.create(title)` → item
3. ItemRepository.save(item)
4. Return `{ record_id, title, state }`

## ArchiveItemUseCase

**Input**: `ArchiveItemCommand { record_id: uuid }`
**Logic**:
1. ItemRepository.findById(record_id) → null → THROW 404 NOT_FOUND
2. item.archive() → THROW 422 INVALID_STATE if state != active
3. ItemRepository.save(item)
