---
name: Failure Patterns
description: List, show and resolve failure patterns from the Failure Pattern Memory store. Use when reviewing recurring agent errors, post-mortem analysis, or checking if an error has been seen before.
tier: core
---

# /failure-patterns

Gestiona el Failure Pattern Memory store (SPEC-188 Fase 1).

## Subcommands

```bash
# Initialise the store (idempotent)
bash scripts/failure-pattern-memory.sh init

# Record a pattern (requires SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1)
bash scripts/failure-pattern-memory.sh add --agent <name> --error "<signature>" [--file-glob <glob>] [--lesson "<text>"]

# List patterns
bash scripts/failure-pattern-memory.sh list [--agent <name>] [--status open|acknowledged|resolved]

# Show detail
bash scripts/failure-pattern-memory.sh show <pattern_id>

# Resolve a pattern
bash scripts/failure-pattern-memory.sh resolve <pattern_id> [--lesson "<lesson>"]

# Summary stats (always available)
bash scripts/failure-pattern-memory.sh stats
```

## Feature flag

Activate with: `export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1`

## Ref

- `docs/rules/domain/failure-pattern-memory.md`
- `scripts/failure-pattern-memory.sh`
- `docs/propuestas/SPEC-188-root-cause-investigation-architecture.md` (Fase 1, P1)
