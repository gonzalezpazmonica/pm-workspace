---
name: context-opt-baseline
description: Record baseline cache hit rate snapshot for monitored CLAUDE.md files
model: fast
---

# /context-opt-baseline

Captures the **current global cache hit rate** as the baseline for a monitored
`CLAUDE.md` (workspace root or `projects/*/CLAUDE.md`). The gate compares
future d7/d14 rates against this baseline; if Δ ≤ −5pp the file enters
`alert` status and writes are blocked (only when enforcing prereqs met).

## Usage

```
/context-opt-baseline [<file_path>]
```

`<file_path>` defaults to workspace `CLAUDE.md`. Must match the monitored
pattern.

## Behaviour

1. Verify file is monitored (regex `(^|/)(CLAUDE\.md|projects/[^/]+/CLAUDE\.md)$`).
2. Compute global d14 hit rate from `~/.savia/usage.db`.
3. Take SHA256 snapshot to `~/.savia/context-opt-snapshots/{sha}.md`.
4. Insert / replace row in `context_baselines` with status `baseline_ready`.
5. Append `event=baseline_set` to `output/context-opt-audit.jsonl`.

## Implementation

```bash
python3 scripts/context-opt-gate.py --baseline "${1:-CLAUDE.md}"
```

(The gate script accepts `--baseline <path>` for manual baseline capture.)

## Output

```
[OK] Baseline recorded
  file:     CLAUDE.md
  sha256:   3f2a...
  baseline: 0.936
  snapshot: ~/.savia/context-opt-snapshots/3f2a....md
  status:   baseline_ready
```

## Notes

- Baseline window is the last 14 days at capture time.
- Prerequisites (≥1000 turns in 14d) are required for enforcement, not for
  baseline capture. You may baseline early in dry-run.
- See `docs/specs/SPEC-CONTEXT-OPT-GATE.spec.md` §5.
