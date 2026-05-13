---
name: context-opt-status
description: Show current monitored CLAUDE.md files, baselines, deltas, and gate status
model: fast
---

# /context-opt-status

Reports the state of the Context Optimization Gate: which CLAUDE.md files are
monitored, their baseline hit rates, current d7/d14 measurements, deltas, and
whether the gate is in dry-run or enforcing mode.

## Usage

```
/context-opt-status [--json]
```

## Behaviour

1. Run `scripts/context-opt-measure.py` to refresh d7/d14 deltas.
2. Print a table (or JSON) with one row per monitored file.
3. Report prerequisite status (turns in last 14d vs. 1000 minimum).

## Implementation

```bash
python3 scripts/context-opt-measure.py "$@"
```

## Output (table mode)

```
Global hit rate d7=0.926  d14=0.936
Prereqs: 7159 turns / 14d  (need >=1000)  -> ENFORCING

file                                        baseline    d14     Δpp       status
CLAUDE.md                                      0.936  0.936   +0.00    measuring
projects/foo/CLAUDE.md                         0.910  0.872   -3.80    measuring
projects/bar/CLAUDE.md                         0.945  0.880   -6.50        alert
```

## Status values

- `baseline_pending` — file detected but no baseline captured yet.
- `baseline_ready` — baseline captured, awaiting first measurement window.
- `measuring` — within tolerance (Δ > −5pp).
- `alert` — degraded ≥5pp; gate will block writes when enforcing.
- `reverted` — file reverted to snapshot after alert.

## Notes

- Read-only command; never modifies files or baselines.
- See `docs/specs/SPEC-CONTEXT-OPT-GATE.spec.md` §6.
