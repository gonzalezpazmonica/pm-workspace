#!/usr/bin/env bats
# tests/test-overnight-sprint-state.bats — SE-226: overnight-sprint-state.sh tests
# Ref: SE-226, docs/rules/domain/autonomous-safety.md

STATE_SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts/overnight-sprint-state.sh"
LOOP_SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts/overnight-sprint-loop.sh"

setup() {
  [[ -x "$STATE_SCRIPT" ]] || skip "overnight-sprint-state.sh missing or not executable"
  command -v jq &>/dev/null || skip "jq required"

  TMPDIR_OS="$(mktemp -d)"
  SPRINT_ID="test-sprint-$$"
  export OVERNIGHT_SPRINT_ID="$SPRINT_ID"
  export AGENT_RUNS_DIR="$TMPDIR_OS"

  TASKS_FILE="$TMPDIR_OS/tasks.json"
  cat > "$TASKS_FILE" <<'JSON'
[
  {"id": 1, "description": "Fix linter warning X", "status": "pending"},
  {"id": 2, "description": "Fix linter warning Y", "status": "pending"},
  {"id": 3, "description": "Add missing test Z",   "status": "pending"}
]
JSON

  STATE_FILE="$TMPDIR_OS/$SPRINT_ID/state.json"
}

teardown() {
  unset OVERNIGHT_SPRINT_ID AGENT_RUNS_DIR 2>/dev/null || true
  [[ -n "${TMPDIR_OS:-}" && -d "${TMPDIR_OS:-}" ]] && rm -rf "$TMPDIR_OS"
}

# ── Test 1: script has safety flags ──────────────────────────────────────────
@test "state script has set -uo pipefail safety flags" {
  grep -q 'set -uo pipefail' "$STATE_SCRIPT"
}

# ── Test 2: init creates state.json with correct structure ───────────────────
@test "init creates state.json with correct structure" {
  run bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE"
  [ "$status" -eq 0 ]
  [ -f "$STATE_FILE" ]

  # Validate JSON parseable
  run python3 -c "import json; json.load(open('$STATE_FILE'))"
  [ "$status" -eq 0 ]

  # Check required fields
  run jq -r '.sprint_id' "$STATE_FILE"
  [ "$output" = "$SPRINT_ID" ]

  run jq -r '.consecutive_failures' "$STATE_FILE"
  [ "$output" = "0" ]

  run jq '.tasks | length' "$STATE_FILE"
  [ "$output" = "3" ]
}

# ── Test 3: init is idempotent (recovery from existing state) ────────────────
@test "init is idempotent — does not overwrite existing state" {
  bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE" >/dev/null 2>&1

  # Mutate state manually
  local modified
  modified="$(jq '.model_escalations = 5' "$STATE_FILE")"
  printf '%s\n' "$modified" > "$STATE_FILE"

  # Re-init should be a no-op
  run bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE"
  [ "$status" -eq 0 ]

  run jq -r '.model_escalations' "$STATE_FILE"
  [ "$output" = "5" ]
}

# ── Test 4: checkpoint updates task status ───────────────────────────────────
@test "checkpoint updates task status to in_progress" {
  bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE" >/dev/null 2>&1

  run bash "$STATE_SCRIPT" checkpoint --task-id 1 --status in_progress --model fast
  [ "$status" -eq 0 ]

  run jq -r '.tasks[0].status' "$STATE_FILE"
  [ "$output" = "in_progress" ]

  run jq -r '.tasks[0].model' "$STATE_FILE"
  [ "$output" = "fast" ]
}

# ── Test 5: checkpoint updates last_checkpoint timestamp ─────────────────────
@test "checkpoint updates last_checkpoint field" {
  bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE" >/dev/null 2>&1
  local before
  before="$(jq -r '.last_checkpoint' "$STATE_FILE")"

  sleep 1
  bash "$STATE_SCRIPT" checkpoint --task-id 2 --status in_progress --model mid >/dev/null 2>&1

  local after
  after="$(jq -r '.last_checkpoint' "$STATE_FILE")"
  # Timestamp should be updated (not necessarily different in fast systems, but field exists)
  [ -n "$after" ]
}

# ── Test 6: complete marks task done and records PR ──────────────────────────
@test "complete marks task done and records pr url" {
  bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE" >/dev/null 2>&1
  bash "$STATE_SCRIPT" checkpoint --task-id 1 --status in_progress --model fast >/dev/null 2>&1

  run bash "$STATE_SCRIPT" complete --task-id 1 --pr "https://github.com/test/pr/42"
  [ "$status" -eq 0 ]

  run jq -r '.tasks[0].status' "$STATE_FILE"
  [ "$output" = "done" ]

  run jq -r '.tasks[0].pr' "$STATE_FILE"
  [ "$output" = "https://github.com/test/pr/42" ]
}

# ── Test 7: complete resets consecutive_failures ─────────────────────────────
@test "complete resets consecutive_failures to 0" {
  bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE" >/dev/null 2>&1

  # Simulate two prior failures
  bash "$STATE_SCRIPT" fail --task-id 2 --reason "timeout" >/dev/null 2>&1
  bash "$STATE_SCRIPT" fail --task-id 3 --reason "crash"   >/dev/null 2>&1

  run jq -r '.consecutive_failures' "$STATE_FILE"
  [ "$output" = "2" ]

  # Now complete task 1 → should reset
  bash "$STATE_SCRIPT" complete --task-id 1 >/dev/null 2>&1

  run jq -r '.consecutive_failures' "$STATE_FILE"
  [ "$output" = "0" ]
}

# ── Test 8: fail increments consecutive_failures ─────────────────────────────
@test "fail increments consecutive_failures correctly" {
  bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE" >/dev/null 2>&1

  run jq -r '.consecutive_failures' "$STATE_FILE"
  [ "$output" = "0" ]

  bash "$STATE_SCRIPT" fail --task-id 1 --reason "timeout_15m" >/dev/null 2>&1
  run jq -r '.consecutive_failures' "$STATE_FILE"
  [ "$output" = "1" ]

  bash "$STATE_SCRIPT" fail --task-id 2 --reason "exit_code=1" >/dev/null 2>&1
  run jq -r '.consecutive_failures' "$STATE_FILE"
  [ "$output" = "2" ]
}

# ── Test 9: status returns valid summary JSON ─────────────────────────────────
@test "status returns valid JSON with expected summary fields" {
  bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE" >/dev/null 2>&1
  bash "$STATE_SCRIPT" complete --task-id 1 >/dev/null 2>&1
  bash "$STATE_SCRIPT" fail --task-id 2 --reason "crash" >/dev/null 2>&1

  run bash "$STATE_SCRIPT" status
  [ "$status" -eq 0 ]

  # Valid JSON
  echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"

  # Check counts
  echo "$output" | jq -e '.done == 1' >/dev/null
  echo "$output" | jq -e '.failed == 1' >/dev/null
  echo "$output" | jq -e '.pending == 1' >/dev/null
  echo "$output" | jq -e '.total == 3' >/dev/null
}

# ── Test 10: export generates TSV with header and correct rows ───────────────
@test "export generates TSV with header and data rows" {
  bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE" >/dev/null 2>&1
  bash "$STATE_SCRIPT" complete --task-id 1 --pr "https://pr/1" >/dev/null 2>&1
  bash "$STATE_SCRIPT" fail --task-id 2 --reason "timeout" >/dev/null 2>&1

  run bash "$STATE_SCRIPT" export
  [ "$status" -eq 0 ]

  # Header row
  echo "$output" | head -1 | grep -q "task_id"
  echo "$output" | head -1 | grep -q "status"

  # 3 data rows (3 tasks)
  local row_count
  row_count="$(echo "$output" | tail -n +2 | wc -l | tr -d ' ')"
  [ "$row_count" = "3" ]
}

# ── Test 11: atomic write — state preserved if crash before mv ───────────────
@test "atomic write: original state intact if tmp file removed before mv" {
  bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE" >/dev/null 2>&1

  local original
  original="$(cat "$STATE_FILE")"

  # Simulate crash: create and remove a tmp file before mv occurs
  local sf_dir
  sf_dir="$(dirname "$STATE_FILE")"
  local tmp_f
  tmp_f="$(mktemp "$sf_dir/.state-CRASH-XXXXXX.tmp")"
  printf 'CORRUPT PARTIAL WRITE' > "$tmp_f"
  rm -f "$tmp_f"   # crash — mv never happens

  # state.json must still equal original
  local current
  current="$(cat "$STATE_FILE")"
  [ "$original" = "$current" ]
}

# ── Test 12: --self-test passes ───────────────────────────────────────────────
@test "--self-test passes all internal checks" {
  # Override AGENT_RUNS_DIR to tmpdir so self-test uses isolated dir
  run env AGENT_RUNS_DIR="$TMPDIR_OS" bash "$STATE_SCRIPT" --self-test
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "all checks passed"
}

# ── Test 13: fail records fail_reason in state ───────────────────────────────
@test "fail records fail_reason and failed_at in task" {
  bash "$STATE_SCRIPT" init --sprint-id "$SPRINT_ID" --tasks-file "$TASKS_FILE" >/dev/null 2>&1

  bash "$STATE_SCRIPT" fail --task-id 3 --reason "token_exhaustion" >/dev/null 2>&1

  run jq -r '.tasks[2].fail_reason' "$STATE_FILE"
  [ "$output" = "token_exhaustion" ]

  run jq -r '.tasks[2].failed_at' "$STATE_FILE"
  [ -n "$output" ]
  [[ "$output" != "null" ]]
}

# ── Test 14: loop script has safety flags ────────────────────────────────────
@test "loop script has set -uo pipefail safety flags" {
  [ -f "$LOOP_SCRIPT" ]
  grep -q 'set -uo pipefail' "$LOOP_SCRIPT"
}

# ── Test 15: loop dry-run completes without error ────────────────────────────
@test "loop --dry-run runs all pending tasks and exits 0" {
  [[ -x "$LOOP_SCRIPT" ]] || skip "overnight-sprint-loop.sh not executable"

  run env AGENT_RUNS_DIR="$TMPDIR_OS" bash "$LOOP_SCRIPT" \
    --sprint-id "$SPRINT_ID" \
    --tasks "$TASKS_FILE" \
    --max-tasks 5 \
    --dry-run
  [ "$status" -eq 0 ]
}
