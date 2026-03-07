---
name: ref-list
description: List available resource references and their types
---

---

# /ref-list — List Available Resource References

## Description
List all available resource references for a project. Show reference pattern, description, and example usage.

## Usage
```
/ref-list {project}
```

## Parameters
- **project** — Project name to list references for

## Output Format

Shows a table with columns:
- **Pattern** — @ notation pattern
- **Type** — resource type
- **Description** — what gets resolved
- **Example** — concrete example

## Available Resource Types

### @azure:workitem://{id}
Fetch work item from Azure DevOps.
Example: `@azure:workitem://12345`

### @project:{name}
Load project CLAUDE.md.
Example: `@project:savia`

### @spec:{task-id}
Load SDD specification.
Example: `@spec:ERA-67`

### @team:{project}
Load equipo.md with team structure.
Example: `@team:savia`

### @rules:{project}
Load reglas-negocio.md with business rules.
Example: `@rules:savia`

### @memory:{topic}
Load relevant memory entries by topic.
Example: `@memory:deployment-strategy`

## Output Location
Results saved to: `output/resource-references/{project}-list.md`

## Related
- `/ref-resolve` — Manually resolve a reference
- `resource-references` skill — Full documentation
