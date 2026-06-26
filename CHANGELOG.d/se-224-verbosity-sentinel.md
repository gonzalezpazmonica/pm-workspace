# SE-224 — Headroom verbosity sentinel + effort router

**era**: 235  
**date**: 2026-06-25  
**status**: IMPLEMENTED  
**slices**: Slice 1 + Slice 2

## What

Two PostToolUse/PreToolUse hooks implementing the Headroom pattern
(github.com/chopratejas/headroom) for structural output-token reduction
without LLM overhead.

## Hooks added

### `.opencode/hooks/output-verbosity-sentinel.sh` (PostToolUse)

Classifies the current turn as MECHANICAL / ERROR / NEW_ASK using structural
signals only (zero LLM):

- `MECHANICAL`: `TOOL_OUTPUT` length < 100 chars and no error signals → emits
  `<!-- VERBOSITY_LEVEL:L2 -->` to stderr (hook-specific output). Hint appended
  at end of context — prefix cache not invalidated.
- `ERROR`: `TOOL_RESULT_IS_ERROR=true` or output matches `ERROR:|FAIL:|FATAL`
  → no hint (full reasoning preserved).
- `NEW_ASK`: everything else → no hint.

Master switch: `SAVIA_VERBOSITY_SENTINEL=on|off` (default `on`).

### `.opencode/hooks/output-effort-router.sh` (PreToolUse)

Mirrors classification from the previous turn's output and emits a low-effort
hint for MECHANICAL turns:

```
[EFFORT: low — mechanical turn, brief response sufficient]
```

Allowlist (always NEW_ASK, effort never reduced): `Edit`, `Write`, `Task`.

Master switch: `SAVIA_EFFORT_ROUTER=on|off` (default `on`).

## Registration

Both hooks registered in `.claude/settings.json`:
- `PostToolUse` matcher `.*` → `output-verbosity-sentinel.sh` (async, timeout 3s)
- `PreToolUse` matcher `.*` → `output-effort-router.sh` (async, timeout 3s)

## Telemetry

Both hooks append to `output/verbosity-telemetry.jsonl`:
```json
{"ts":"...","hook":"verbosity-sentinel","classification":"MECHANICAL","verbosity":"L2","output_len":12,"tool":"Bash"}
```

## Tests

`tests/test-se224-verbosity-sentinel.bats` — 22 tests, all passing.

Coverage:
- Hook existence, executable bit, set -uo pipefail, bash -n syntax
- Master switch off → exit 0 no output
- ERROR classification (is_error=true, ERROR: prefix)
- MECHANICAL classification (short output)
- NEW_ASK classification (long output)
- Allowlist (Edit/Write/Task bypass effort reduction)
- Telemetry dir absent → no crash

## Expected impact

~29% output token reduction on mechanical turns (tool pass-through, file reads,
test pass confirmations) based on Headroom benchmarks.
