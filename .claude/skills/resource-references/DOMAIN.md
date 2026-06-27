# domain: resource-references

## Scope
Defines the domain for referenciable resources using @ notation for automatic context inclusion across pm-workspace.

## Core Concepts

### Reference Patterns
- Format: `@{type}:{identifier}`
- Types: azure:workitem, project, spec, team, rules, memory
- Lazy resolution on first invocation

### Approved Sources
- Azure DevOps API endpoints
- Local project files (.claude/, docs/)
- Memory database entries
- Configuration files (CLAUDE.md, equipo.md, reglas-negocio.md)

### Session Caching
Resources resolved within a session are cached to avoid redundant fetches and improve performance.

## Constraints
1. Unknown references → warning, not error
2. Max 5 simultaneous resolutions
3. Security: only approved sources
4. Circular references not allowed
5. Timeout: 10s per resolution

## Integration Points
- Skills evaluation engine
- Command handlers
- Rule validation engine
- Memory system
