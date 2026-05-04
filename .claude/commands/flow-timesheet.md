---
name: flow-timesheet
description: Log hours spent on a task
argument-hint: "<@handle> <task_id> <hours> [notes]"
allowed-tools: [Bash]
model: fast
context_cost: low
---

# Log Timesheet

**Arguments:** $ARGUMENTS

## Parámetros

- `<@handle>` — Developer handle
- `<task_id>` — Task being worked on
- `<hours>` — Hours spent
- `[notes]` — Optional work description

## Ejecución

Execute: `bash scripts/savia-flow-timesheet.sh log <@handle> <task_id> <hours> [notes]`

## Almacenamiento

📁 Stored in: timesheets/{handle}/{YYYY-MM}/entries.log
