---
globs: [".claude/commands/**", ".claude/skills/**"]
---
# resource-resolution — Rule for @ Reference Resolution

## Principle

@ references are resolved lazily at invocation time, not upfront. This optimizes context usage while ensuring referenced resources are available when needed.

## Resolution Process

1. **Detect**: Scan user input and skill definitions for @ patterns
2. **Lazy Load**: Only load when first referenced, not during parsing
3. **Cache**: Store resolved content for session duration
4. **Limit**: Maximum 5 simultaneous resolutions
5. **Error Handling**: Unknown references → warning, not error

## Supported Types

```
@azure:workitem://{id}     → Azure DevOps work item
@project:{name}            → Project CLAUDE.md
@spec:{task-id}            → SDD specification
@team:{project}            → equipo.md (team structure)
@rules:{project}           → reglas-negocio.md
@memory:{topic}            → Relevant memory entries
```

## Caching Strategy

- **Duration**: Session (until /clear or /compact)
- **Storage**: Memory (not persisted)
- **Invalidation**: On /compact or /clear
- **Reuse**: Identical references served from cache

## Limits

- **Max simultaneous**: 5 resolutions
- **Timeout per resolution**: 10 seconds
- **Max retries**: 1 (automatic)
- **Circuit breaker**: Unknown reference → warning, skip

## Security

- Only resolve from approved sources (predefined list)
- Validate reference pattern before resolution
- No execution of resolved content
- No circular references

## Example

User says: "Check @spec:ERA-67 for requirements and @rules:savia for compliance"
1. Reference 1: @spec:ERA-67 → resolved (loaded from file)
2. Reference 2: @rules:savia → resolved (loaded from file)
3. Both cached for session
4. If reference appears again → served from cache

## Related

- `resource-references` skill — 6 resource types
- `/ref-list` — List available references
- `/ref-resolve` — Manually resolve and preview
