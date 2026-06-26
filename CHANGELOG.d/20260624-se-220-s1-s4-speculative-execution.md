## SE-220 S1-S4 — Speculative Tool Execution (2026-06-24)

### Added

#### Slice 1 — Tool call predictor + read-only whitelist

- `scripts/speculative-tool-predictor.py` — Updated from S0. New additions:
  - `READ_ONLY_WHITELIST = frozenset(["Read", "Grep", "Glob", "Bash"])` — idempotent tools
  - Output includes `whitelist_only: bool` — true iff all predicted tools are in the whitelist
  - `--validate` mode: accepts `{predicted_tools, actual_tool}`, exits 0 on match / 1 on no-match

- `scripts/speculative-tool-execution.py` — Main orchestrator:
  - Accepts `{intent, available_tools, session_id}` via stdin
  - If `whitelist_only=true` AND `confidence >= 0.5`: launches background pre-execution
  - Cache stored in `/tmp/savia-speculative-cache/` with TTL 30s
  - Atomic writes (`.tmp` rename) for concurrency safety
  - `--resolve` mode for cache-hit lookup
  - Telemetry appended to `output/speculative-execution-telemetry.jsonl`

#### Slice 2 — Async pre-execution wrapper

- `.opencode/hooks/speculative-pre-execute.sh` — PostToolUse hook:
  - Guard: `SAVIA_SPECULATIVE_EXECUTION=on` required (default: off, opt-in per SPEC-186)
  - Launches orchestrator in background (non-blocking)
  - Fail-soft: always exits 0

- `scripts/speculative-cache-manager.py` — Standalone cache manager:
  - Commands: `get`, `set`, `del`, `clean`, `stats`
  - File locking via `fcntl` for concurrent safety
  - Atomic write via temp file rename
  - TTL-based eviction; `get` exits 1 on miss

#### Slice 3 — Skill pre-loading

- `.opencode/hooks/speculative-skill-preload.sh` — PreToolUse hook:
  - Activates on `SAVIA_SPECULATIVE_EXECUTION=on|shadow`; Task tool only
  - 13 intent patterns mapped to skill hints
  - Shadow mode: telemetry only, no output mutation
  - On mode: emits `[SPECULATIVE_SKILL_HINT: skill-name]` as additionalContext

#### Slice 4 — Telemetry dashboard

- `scripts/speculative-telemetry-report.sh` — Dashboard:
  - Reads `output/speculative-execution-telemetry.jsonl`
  - Computes: cache_hit_rate, avg_latency_saved_ms, prediction_accuracy, speculative_executions
  - Verdict: GO / KILL / TUNE / NO_DATA
  - GO: cache_hit_rate >= 0.30 AND avg_latency_saved_ms >= 100
  - KILL: prediction_accuracy < 0.50 OR cache_hit_rate < 0.10
  - Output: text table (default) or JSON (`--json`)

### Tests

- `tests/scripts/test_speculative_execution.py`: 23 pytest tests — all green
- `tests/bats/test-se-220-speculative.bats`: 25 BATS tests — all green
- S0 regression: 16 pytest + 10 BATS all green

### Ref

- Spec: `docs/propuestas/SE-220-speculative-tool-execution.md` (IMPLEMENTED)
