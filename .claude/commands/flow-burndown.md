---
name: flow-burndown
description: Show sprint burndown chart data
argument-hint: "<sprint_id>"
allowed-tools: [Bash]
model: fast
context_cost: low
---

# Burndown Chart

**Arguments:** $ARGUMENTS

## Parámetros

- `<sprint_id>` — Sprint identifier

## Ejecución

Execute: `bash scripts/savia-flow-sprint.sh burndown <sprint_id>`

## Output

Shows daily task counts by column (todo, in-progress, review, done)
