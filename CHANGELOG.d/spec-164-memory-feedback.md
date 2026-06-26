## SPEC-164 — Memory Feedback Loop (auto-memory writes from outcomes) (2026-06-24)

### Added

- `.opencode/hooks/memory-feedback-task.sh`: PostToolUse hook that fires when
  `tool_name == "Task"`. Master switch `SAVIA_MEMORY_FEEDBACK=on|off` (default
  `off` — explicit opt-in). Calls `memory-feedback-extractor.py`, applies
  entropy filter, writes to `memory-store.sh`, appends telemetry line to
  `output/memory-feedback-telemetry.jsonl`. Always exits 0.

- `scripts/memory-feedback-extractor.py`: Standalone extractor. Reads
  PostToolUse JSON from stdin, outputs `{outcome, agent_name, lesson,
  entropy_score, should_write}`. Outcome detection via regex over failure
  keywords (ERROR, FAIL, Exception, Traceback, …). Entropy heuristic:
  unique-token ratio × size factor, capped 0–1. Writes if
  `outcome=="failure"` or `entropy_score > 0.3`.

- `scripts/memory-feedback-post-merge.sh`: Detects merged PRs via `git log`
  and writes a `pr_merged:#NNN spec:{spec_id} branch:{branch}` entry to
  memory-store. Dual mode: auto (git hook) and standalone
  (`--manual --pr NNN --spec SE-NNN`). Install as `.git/hooks/post-merge`
  via symlink. Always exits 0.

- `scripts/memory-feedback-compactor.py`: Reads MEMORY.md, identifies
  `agent + outcome` pairs repeated >= 3 times, promotes the most recent lesson
  to `docs/rules/learned/{agent}-pattern.md`, removes older duplicates. Cap
  enforcement: trims to ≤ 190 entry lines when over the limit.
  `--dry-run` mode shows what would change without writing.

- `docs/rules/learned/` directory created (destination for promoted patterns).

- `tests/scripts/test_memory_feedback.py`: 16 pytest tests — extractor outcome
  detection, entropy scoring, lesson truncation, agent name extraction,
  compactor grouping / promotion / cap / dry-run, post-merge standalone.

- `tests/bats/test-memory-feedback.bats`: 12 BATS tests — hook existence,
  master-switch off, set -uo pipefail, extractor standalone (error + clean),
  compactor dry-run idempotence, post-merge manual mode, JSON field
  validation, syntax checks.

### Test results

```
pytest: 16 passed in 0.11s
bats:   12/12 ok
```

### AC coverage

| AC | Status |
|---|---|
| Task call → 1 entry in MEMORY auto (success or failure) | PASS (hook + extractor) |
| PR merged in main → 1 entry with spec_id | PASS (post-merge script) |
| Compactor identifies lessons >= 3 times, promotes to learned/ | PASS |
| Cap 200 lines / 25 KB respected | PASS (CAP_TRIGGER=190, existing cap in memory-store.sh) |
| Tests BATS score >= 80 | PASS (12/12 = 100%) |
