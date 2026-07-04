---
name: UA Diff
description: Analyze impact of uncommitted changes on the codebase knowledge graph
tier: core
---

# /ua-diff — Change Impact Analysis

Analyzes uncommitted changes and estimates their impact on the codebase knowledge
graph. Reports how many nodes (files, functions, classes, dependencies) are
affected by the current working tree changes.

Used as CI gate G16 (WARN, non-blocking) in `scripts/pr-plan-gates.sh`.

## Usage

```
/ua-diff             # show impact summary
```

## CI Gate Usage

```bash
ua_diff_count=$(bash scripts/ua-bridge.sh diff --count)
[[ $ua_diff_count -gt 50 ]] && echo "WARN: diff impact >50 nodes affected"
```

## Output

- Number of nodes affected
- WARN if more than 50 nodes are impacted

## Notes

If UA is not installed, `diff --count` returns `0` (graceful degradation).
Bridge: `bash scripts/ua-bridge.sh diff [--count]`

Ref: SPEC-SE-088-UA-ADOPT
