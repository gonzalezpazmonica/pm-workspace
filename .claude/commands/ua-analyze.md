---
name: UA Analyze
description: Analyze codebase with Understand-Anything to generate knowledge graph
---

# /ua-analyze — Codebase Knowledge Graph

Analyzes a codebase and generates a `knowledge-graph.json` with structural nodes
(files, functions, classes, dependencies), domain nodes (business processes,
flows), and knowledge nodes (entities, claims, relations).

Uses Understand-Anything multi-agent pipeline. If UA is not available, falls back
to `scripts/knowledge-graph.py`.

## Usage

```
/ua-analyze .               # analyze current workspace
/ua-analyze ~/projects/foo  # analyze a specific project
```

## Fallback (UA not installed)

```bash
python3 scripts/knowledge-graph.py .
```

## Output

- `knowledge-graph.json` — nodes + edges for all codebase entities
- Interactive dashboard via `/ua-dashboard` at `http://localhost:5174`

## Prerequisites

Run `/ua-install` first if Understand-Anything is not installed.
Bridge: `bash scripts/ua-bridge.sh analyze [path]`

Ref: SPEC-SE-088-UA-ADOPT
