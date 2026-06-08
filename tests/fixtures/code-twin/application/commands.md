---
module_id: item-commands
layer: application
version: "1.0.0"
last_sync: "2026-06-08T14:30:00Z"
token_budget: 200
stale_after_days: 14
depends_on: []
provides:
  - CreateItemCommand
  - ArchiveItemCommand
  - UpdateItemTitleCommand
status: STABLE
---
# Item Commands — fixture-project

Commands are write-only DTOs. No logic, no side effects at construction.

## CreateItemCommand

| field | type | required |
|-------|------|----------|
| title | string | true |

## ArchiveItemCommand

| field | type | required |
|-------|------|----------|
| record_id | uuid | true |

## UpdateItemTitleCommand

| field | type | required |
|-------|------|----------|
| record_id | uuid | true |
| new_title | string | true |
