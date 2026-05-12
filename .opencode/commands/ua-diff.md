---
name: ua-diff
description: Analyze impact of uncommitted changes on the codebase graph
---

# /ua-diff — Change Impact Analysis

Analyzes uncommitted changes and estimates their impact on the codebase
using Understand-Anything's diff analysis pipeline.

Reports how many nodes (files, functions, classes, dependencies) are
affected by the current working tree changes.

## Usage

```
/ua-diff
```

## Output

- Number of nodes affected
- WARN if more than 50 nodes are impacted
