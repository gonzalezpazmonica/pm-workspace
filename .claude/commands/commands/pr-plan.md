---
name: pr-plan
description: "Pre-flight checklist: 15 gates (G0-G14) before push/PR. Prevents CI failures."
argument-hint: "[--dry-run] [--skip-push] [--title 'PR title']"
allowed-tools: [Bash, Read, Grep, Glob]
---

Run the PR pre-flight checklist. Execute:

```bash
bash scripts/pr-plan.sh $ARGUMENTS
```

Show the full output to the user. If any gate fails, explain the fix.
