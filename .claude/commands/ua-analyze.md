---
name: UA Analyze
description: Analyze codebase with Understand-Anything to generate knowledge graph
tier: core
---

# /ua-analyze — Codebase Knowledge Graph

Analyzes a codebase and generates a `knowledge-graph.json` with structural nodes
(files, functions, classes, dependencies), domain nodes (business processes,
flows), and knowledge nodes (entities, claims, relations).

Uses Understand-Anything multi-agent pipeline. If UA is not installed the bridge
exits 0 with a notice; if UA is installed but `opencode` is missing (exit 2) or the
run fails (exit 1), it reports the error. A missing path is exit 1.

## Usage

```
/ua-analyze .               # analyze current workspace
/ua-analyze ~/projects/foo  # analyze a specific project
```

## Fallback (UA not installed)

There is no codebase-analysis fallback. The closest is Savia's memory graph,
which takes no path (it reads the workspace memory, roadmap and rules):

```bash
python3 scripts/knowledge-graph.py build
```

## Output

- `knowledge-graph.json` — nodes + edges for all codebase entities
- Interactive dashboard via `/ua-dashboard` at `http://localhost:5174`

## Prerequisites

Run `/ua-install` first if Understand-Anything is not installed.
Bridge: `bash scripts/ua-bridge.sh analyze [path]`

Ref: SPEC-SE-088-UA-ADOPT
