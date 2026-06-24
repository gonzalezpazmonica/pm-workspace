---
context_tier: L2
token_budget: 900
spec: SE-228
slice: S4
---

# Loop Budget Schema — `loop-budget.md`

> Canonical schema for the per-skill loop-budget declaration file.
> Read at startup by `scripts/loop-budget-check.sh`.
> Ref: SE-228 Slice 4, `docs/propuestas/SE-228-loop-engineering-patterns.md`

## File location

```
output/loop-budget/<skill-name>/loop-budget.md
```

One file per skill. The `LOOP_BUDGET_DIR` env var overrides the default base
path (`$PROJECT_ROOT/output/loop-budget`) for testing isolation.

## Schema

```yaml
# loop-budget.md — Loop budget declaration for <skill>
skill: <nombre>
daily_token_cap: 500000        # tokens/día; 0 = unlimited
max_tasks_per_run: 20          # max items procesados por run
max_attempts_per_task: 3       # intentos antes de escalar al humano
kill_if:                       # condiciones de parada automática
  - ci_red_3d                  # CI rojo 3 días consecutivos
  - no_progress_2d             # sin items resueltos en 2 días
  - escalations_gt: 5          # >5 escalaciones en un día
pause_on_weekend: true         # no ejecutar sábado/domingo
last_reset: "YYYY-MM-DD"       # fecha del último reset del contador diario
tokens_used_today: 0           # actualizado en cada run
```

## Field reference

| Field | Type | Default | Description |
|---|---|---|---|
| `skill` | string | required | Name of the skill this budget applies to. Must match the directory name under `LOOP_BUDGET_DIR`. |
| `daily_token_cap` | integer | 500000 | Maximum tokens consumable per calendar day. `0` means unlimited — the cap check is skipped entirely. |
| `max_tasks_per_run` | integer | 20 | Maximum number of items the skill may process in a single autonomous run. Prevents runaway loops on large backlogs. |
| `max_attempts_per_task` | integer | 3 | Attempts before a task is marked as "escalate to human". Maps to `AGENT_MAX_CONSECUTIVE_FAILURES` in `autonomous-safety.md`. |
| `kill_if` | list | [] | List of automatic kill conditions checked at startup. See section below. |
| `pause_on_weekend` | boolean | true | When `true`, the script exits 1 on Saturday and Sunday. Prevents unattended runs when reviewers are unavailable. |
| `last_reset` | date string | today | ISO-8601 date of the last daily counter reset. If it differs from today, `tokens_used_today` is reset to 0 before the cap check. |
| `tokens_used_today` | integer | 0 | Running counter of tokens consumed today. Updated by `--update-tokens N`. Reset when `last_reset` is before today. |

## Kill conditions (`kill_if`)

| Condition | Trigger |
|---|---|
| `ci_red_3d` | File `.loop-ci-red-streak` exists in `LOOP_BUDGET_DIR/<skill>/` and its integer content is `>= 3`. Indicates CI has been red for 3+ consecutive days — loop must stop until humans fix it. |
| `no_progress_2d` | Reserved for future implementation. File `.loop-no-progress-streak` with value `>= 2`. |
| `escalations_gt: N` | Reserved for future implementation. Checked against a counter file `.loop-escalations-today`. |

## How `loop-budget-check.sh` reads this file

The script uses `grep` + `sed` to extract YAML scalar values without requiring
a YAML parser. The parsing is line-based: it looks for `^field: value` patterns.
`kill_if` items are extracted as a list by scanning lines between `kill_if:` and
the next top-level key.

## Integration points

- `scripts/loop-budget-check.sh` — gate script; call at start of every autonomous run
- `docs/rules/domain/autonomous-safety.md` — `max_attempts_per_task` maps to `AGENT_MAX_CONSECUTIVE_FAILURES`
- `templates/loop-budget.md.template` — copy to bootstrap a skill's budget file

## Example (overnight-sprint)

```yaml
skill: overnight-sprint
daily_token_cap: 500000
max_tasks_per_run: 20
max_attempts_per_task: 3
kill_if:
  - ci_red_3d
  - no_progress_2d
pause_on_weekend: true
last_reset: "2026-06-25"
tokens_used_today: 0
```
