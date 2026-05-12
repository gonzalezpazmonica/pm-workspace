---
name: pr-plan
description: "Pre-flight checklist: 15 gates (G0-G14) before push/PR. Prevents CI failures."
argument-hint: "[--dry-run] [--skip-push] [--title 'PR title'] [--base remote/branch]"
allowed-tools: [Bash, Read, Grep, Glob]
---

Run the PR pre-flight checklist. Execute:

```bash
bash scripts/pr-plan.sh $ARGUMENTS
```

Show the full output to the user. If any gate fails, explain the fix.

## PR target resolution

The base ref against which gates compare divergence is resolved in this order:

1. `--base remote/branch` flag (explicit override).
2. `SAVIA_PR_BASE` env var.
3. Auto-detect from current branch's open PR via `gh pr view --json baseRefName,baseRefRepository` (maps PR base repo to local remote).
4. Fallback: `origin/main`.

Use `--base public/main` when working from a fork remote (e.g. `public`) targeting a different upstream than `origin`.
