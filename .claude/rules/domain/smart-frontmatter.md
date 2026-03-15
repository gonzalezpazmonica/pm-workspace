---
globs: [".claude/commands/**"]
---
# Smart Command Frontmatter — Advanced Fields

> Commands declare their resource needs for optimal model selection and tool access.

---

## Fields

| Field | Type | Purpose | Example |
|---|---|---|---|
| `argument-hint` | string | Autocomplete syntax hint | `"[project] [--format csv]"` |
| `allowed-tools` | list | Restrict tool access | `[Read, Glob, Grep]` |
| `model` | string | Override model selection | `haiku`, `sonnet`, `opus` |
| `context_cost` | string | Token budget category | `low`, `medium`, `high` |

## Model Selection Taxonomy

| Category | Model | Criteria | Examples |
|---|---|---|---|
| **Lightweight** | haiku | Read-only, listing, simple queries | help, profile-show, memory-search |
| **Standard** | sonnet | Analysis, reporting, moderate logic | sprint-status, pr-review, debt-analyze |
| **Complex** | opus | Multi-step orchestration, deep analysis | project-audit, governance-audit, spec-generate |

## allowed-tools Guidelines

| Command type | Typical tools |
|---|---|
| Read-only queries | `[Read, Glob, Grep]` |
| Reporting with output | `[Read, Glob, Grep, Bash, Write]` |
| Full orchestration | `[Read, Write, Edit, Bash, Glob, Grep, Task]` |

## Validation

`validate-commands.sh` checks:
- `model` must be one of: `haiku`, `sonnet`, `opus` (if present)
- `allowed-tools` must be valid tool names (if present)
- `context_cost` must be one of: `low`, `medium`, `high` (if present)

## Rollout Strategy

Priority rollout to highest-traffic commands first:
1. Navigation: help, savia-gallery, profile-show
2. Sprint: sprint-status, daily-routine, board-flow, my-sprint
3. Reporting: report-executive, ceo-report, kpi-dashboard
4. Quality: pr-review, governance-audit, spec-status
5. All remaining commands incrementally
