---
name: context-opt-revert
description: Revert a monitored CLAUDE.md to its baseline snapshot when in alert status
model: fast
---

# /context-opt-revert

When a monitored `CLAUDE.md` enters `alert` status (Δ ≤ −5pp on d14 cache hit
rate), this command restores the file to its captured baseline snapshot.

## Usage

```
/context-opt-revert <file_path> [--force]
```

`<file_path>` must be in `context_baselines` and have status `alert`. Use
`--force` to revert from any non-baseline_pending status (e.g. measuring with
small negative drift).

## Behaviour

1. Look up row in `context_baselines` for `<file_path>`.
2. Reject unless status is `alert` (or `--force` is set).
3. Copy `snapshot_path` over `<file_path>` (preserving original mode).
4. Update row: status='reverted', updated_at=now.
5. Append `event=revert` to `output/context-opt-audit.jsonl`.

## Implementation

```bash
python3 scripts/context-opt-gate.py --revert "$@"
```

(The gate script accepts `--revert <file_path> [--force]` for restoration.)

## Output

```
[OK] Reverted projects/foo/CLAUDE.md
  from: 8ba1... (current)
  to:   3f2a... (baseline snapshot)
  status: reverted
  next: review the recent edits and re-run /context-opt-baseline when ready.
```

## Safety

- Only reverts files inside the workspace.
- Refuses to revert if snapshot SHA does not exist on disk.
- Does **not** stage/commit; user reviews and commits manually.

## Notes

- After revert, re-baseline only once the cache hit rate has recovered.
- See `docs/specs/SPEC-CONTEXT-OPT-GATE.spec.md` §5 (revert path).
