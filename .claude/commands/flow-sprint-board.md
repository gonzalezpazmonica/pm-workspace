---
name: flow-sprint-board
description: Display sprint board with task counts by column
argument-hint: "<sprint_id>"
allowed-tools: [Bash]
model: haiku
context_cost: low
---

# Sprint Board

**Arguments:** $ARGUMENTS

## Parámetros

- `<sprint_id>` — Sprint identifier

## Ejecución

Execute: `bash scripts/savia-flow-sprint.sh board <sprint_id>`

## Output

Shows counts for: todo | in-progress | review | done
