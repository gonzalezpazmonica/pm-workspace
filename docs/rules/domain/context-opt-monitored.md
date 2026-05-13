# Context Optimization — Monitored Files

> SPEC-CONTEXT-OPT-GATE — load on demand when editing `CLAUDE.md` files.

## What is monitored

The Context Optimization Gate watches writes (`Edit` / `Write` tool calls) to:

- `CLAUDE.md` at the workspace root.
- `projects/<name>/CLAUDE.md` for any active project.

Pattern: `(^|/)(CLAUDE\.md|projects/[^/]+/CLAUDE\.md)$` (case-insensitive).

The gate runs as a PreToolUse hook
(`.opencode/hooks/context-opt-gate.sh`) before the write is applied.

## What it does

For each monitored write:

1. Take a SHA256 snapshot of the **current** file before the edit
   (`~/.savia/context-opt-snapshots/{sha}.md`).
2. Look up the file in `~/.savia/usage.db` table `context_baselines`.
3. Decide: **allow** (dry-run / measuring / no baseline) or **block** (alert +
   prerequisites met + not bypassed).

## Modes

| Condition | Mode | Outcome |
|---|---|---|
| `<1000` turns in last 14d | dry-run | always allow; log `event=dry_run` |
| Baseline not captured | dry-run | allow; log `event=no_baseline` |
| `status='measuring'` | measuring | allow; log delta |
| `status='alert'` + prereqs met | enforcing | exit 2 (block) |
| `SAVIA_CONTEXT_OPT_BYPASS=1` | bypass | allow; log `event=bypass` |
| `SAVIA_CONTEXT_OPT_ENABLED=false` | disabled | exit 0 immediately |

## Threshold

Δ ≤ −5pp on d14 global cache hit rate → status='alert' → block.
Computed by `scripts/context-opt-measure.py` (called by `/context-opt-status`).

## Bypass etiquette

`SAVIA_CONTEXT_OPT_BYPASS=1` is for emergencies and short editing windows.
Every bypass is logged with timestamp and reason (set
`SAVIA_CONTEXT_OPT_BYPASS_REASON="..."` for traceability). Routine bypass is a
signal that the file should be re-baselined, not that the gate should be
disabled.

## Operator workflow

```
/context-opt-status              # see deltas + prereq state
/context-opt-baseline CLAUDE.md  # capture initial baseline
# ... edit cycles, /context-opt-status shows drift ...
/context-opt-revert <file>       # if alert and edits were not worth the cost
```

## References

- Spec: `docs/specs/SPEC-CONTEXT-OPT-GATE.spec.md`
- Schema: `scripts/context-opt-gate.py` (`SCHEMA` constant)
- Gate logic: `scripts/context-opt-gate.py`
- Measure logic: `scripts/context-opt-measure.py`
- Hook: `.opencode/hooks/context-opt-gate.sh`
- Audit log: `output/context-opt-audit.jsonl`
- Snapshots: `~/.savia/context-opt-snapshots/{sha}.md`
