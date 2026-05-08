---
name: flow-task-assign
description: Assign task to a team member
argument-hint: "<task_id> <@handle>"
allowed-tools: [Bash]
model: github-copilot/claude-sonnet-4.5
context_cost: low
---

# Assign Task

**Arguments:** $ARGUMENTS

## Parámetros

- `<task_id>` — Task identifier
- `<@handle>` — Developer to assign

## Ejecución

1. Execute: `bash scripts/savia-flow-tasks.sh assign <task_id> <@handle>`
2. Confirm assignment

⚡ /compact — Ejecuta para liberar contexto
