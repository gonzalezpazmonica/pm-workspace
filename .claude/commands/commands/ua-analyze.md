---
name: ua-analyze
description: Generate knowledge graph for any codebase using Understand-Anything
---

# /ua-analyze — Codebase Knowledge Graph

Analyzes a codebase and generates a `knowledge-graph.json` with files,
functions, classes, dependencies, and domain concepts.

Uses [Understand-Anything](https://github.com/Lum1104/Understand-Anything),
a multi-agent pipeline compatible with 13 languages.

## Usage

```
/ua-analyze ~/claude           # analyze Savia workspace
/ua-analyze ~/projects/foo     # analyze a specific project
```

## Output

- `~/.opencode/understand-anything/knowledge-graph.json`
- Interactive dashboard at `http://localhost:5174` (via `/ua-dashboard`)

## Prerequisites

Run `/ua-install` first if Understand-Anything is not installed.
