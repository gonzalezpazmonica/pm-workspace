---
globs: [".opencode/commands/code-audit*", ".opencode/commands/sprint-review*", ".opencode/commands/pr-*"]
---
# Severity Classification — Rule of Three

## Purpose

Classify quality issues by severity using the Rule of Three pattern:
3+ occurrences → CRITICAL, 2 → WARNING, 1 → INFO. Prevents both
over-reaction to single events and under-reaction to systemic patterns.

Inspired by kimun's duplicate severity classification and adapted
for PM-Workspace quality dimensions.

## Classification Thresholds

### PR Quality

```
Metric                    CRITICAL        WARNING         INFO
─────────────────────────────────────────────────────────────
Files changed             > 30            15-30           < 15
Lines changed             > 1000          500-1000        < 500
Files over 150 lines      ≥ 3             1-2             0
Missing tests             ≥ 3 untested    1-2 untested    0
Commits without prefix    ≥ 3             1-2             0
```

### Sprint Health

```
Metric                    CRITICAL        WARNING         INFO
─────────────────────────────────────────────────────────────
Velocity deviation        > 50%           20-50%          < 20%
Blocked items             ≥ 3             1-2             0
Unestimated PBIs          ≥ 3             1-2             0
Overdue tasks             ≥ 3             1-2             0
Scope changes mid-sprint  ≥ 3             1-2             0
```

### Context Health

```
Metric                    CRITICAL        WARNING         INFO
─────────────────────────────────────────────────────────────
Context usage             > 85%           70-85%          < 70%
Files loaded this session ≥ 20            10-20           < 10
Stale memory entries      ≥ 10            5-10            < 5
Dormant rules (0 refs)    ≥ 5             2-4             0-1
```

### Code Quality (from audits)

```
Metric                    CRITICAL        WARNING         INFO
─────────────────────────────────────────────────────────────
Cognitive complexity      > 25            15-25           < 15
Duplicated blocks         ≥ 3             1-2             0
Functions > 50 lines      ≥ 3             1-2             0
Missing error handling    ≥ 3             1-2             0
```

## Escalation Protocol

**CRITICAL** → Block action. Require human review before proceeding.
Show in red. Include in PR Guardian digest.

**WARNING** → Allow action with advisory. Show in yellow.
Log for pattern tracking.

**INFO** → Proceed normally. Track silently. Include in periodic
reports only.

## Temporal Escalation

If the same WARNING appears in 3 consecutive sprints → auto-escalate
to CRITICAL. Pattern persistence indicates systemic issue.

If a CRITICAL is resolved and stays clean for 2 sprints →
auto-downgrade to INFO.

## Application

Commands that SHOULD use severity classification:
- PR Guardian (all gates)
- `/sprint-review` and `/sprint-retro`
- `/code-audit` and `/perf-audit`
- `/score-diff` (regression classification)
- `/hub-audit` (dormant rule detection)
- `/context-budget` (context health)

## References

- kimun (lnds/kimun). Rule of Three for duplicate severity
- SonarQube. Issue severity classification model
- scoring-curves.md for normalization breakpoints
