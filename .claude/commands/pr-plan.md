---
name: pr-plan
description: "Pre-flight checklist: 10 gates before push/PR. Prevents CI failures."
argument-hint: "[--dry-run] [--skip-push] [--title 'PR title']"
allowed-tools: [Bash, Read, Grep, Glob]
model: sonnet
---

Run the PR pre-flight checklist. Execute:

```bash
bash scripts/pr-plan.sh $ARGUMENTS
```

Show the full output to the user. If any gate fails, explain the fix.
