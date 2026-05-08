---
name: risk-policy
description: Display and manage risk scoring thresholds and policies
---

# Command: /risk-policy

Display current risk scoring policy and thresholds. Optionally update thresholds per project.

## Usage

```
/risk-policy
/risk-policy --update
/risk-policy --project {project-id}
```

## Parameters

- `--update` (optional): Modify thresholds interactively
- `--project` (optional): Show policy for specific project only

## Output

Displays risk scoring policy with thresholds and weighting factors.
