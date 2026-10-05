---
name: UA Diff
description: Analyze impact of uncommitted changes on the codebase knowledge graph
tier: core
---

# /ua-diff — Change Impact Analysis

Counts changed tracked files (staged + unstaged, deduplicated) as a proxy for
the impact on the codebase knowledge graph. It is a file count, not a node count.

Not wired into `scripts/pr-plan-gates.sh` (G16 there is eval-lint); the snippet
below is for a custom WARN gate.

## Usage

```
/ua-diff             # show impact summary
```

## CI Gate Usage

```bash
ua_diff_count=$(bash scripts/ua-bridge.sh diff --count)
[[ $ua_diff_count -gt 50 ]] && echo "WARN: diff impact >50 files changed"
```

## Output

- Number of changed files
- WARN if more than 50 files changed

## Notes

If UA is not installed, `diff --count` returns `0` (graceful degradation).
Outside a git work tree it prints `0` and warns on stderr.
Bridge: `bash scripts/ua-bridge.sh diff [--count]`

Ref: SPEC-SE-088-UA-ADOPT
