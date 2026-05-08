---
name: weekly-report
description: Weekly project status report generator — consolidates sprint, git, PRs, and capacity
model: mid
context_cost: medium
---

# weekly-report — Weekly project status report generator
# Trigger: `/weekly-report` or scheduled via cron

## Purpose
Generate a structured weekly status report for the active project, pulling data from Azure DevOps, git log, and project documentation.

## Activation
- `/weekly-report [project]` — generate report for project
- `/weekly-report --team` — generate team-wide report
- `/weekly-report --schedule` — configure cron schedule

## Pipeline
1. Detect active project via `project-context.sh`
2. Pull sprint status from ADO bridge
3. Pull git activity (commits, branches merged)
4. Pull open PRs and their status
5. Consolidate into template `templates/weekly-report.md.j2`
6. Output to `output/reports/YYYYMMDD-weekly-{project}.md`

## Template variables
- `{{sprint_status}}` — items completed, in progress, blocked
- `{{git_activity}}` — commits this week, branches merged
- `{{pr_status}}` — open PRs, reviews pending
- `{{team_capacity}}` — hours available vs used
- `{{blockers}}` — blocked items with age
