#!/usr/bin/env bats
# test-se-217-time-budget.bats — SE-217 Slice 2: Time Budget Enforcer
# Ref: docs/propuestas/SE-217-autoresearch-patterns.md
# Coverage target: >=12 tests

SCRIPT="scripts/agent-time-budget.sh"
RUN_LOG="scripts/agent-run-log.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR_TEST="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
  export AGENT_RUN_LOG_DIR="${TMPDIR_TEST}/output"
  export AGENT_RUN_LOG_FILE="${TMPDIR_TEST}/output/agent-run-log-test.tsv"
  mkdir -p "${TMPDIR_TEST}/output"
}

teardown() {
  rm -rf "${TMPDIR_TEST}" 2>/dev/null || true
}

# ── 1. Script exists and is executable ──────────────────────────────────────
@test "SE-217-S2: script exists" {
  [ -f "$SCRIPT" ]
}

@test "SE-217-S2: script is executable" {
  [ -x "$SCRIPT" ]
}

# ── 2. set -uo pipefail present ─────────────────────────────────────────────
@test "SE-217-S2: set -uo pipefail present in script" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

# ── 3. cmd that completes before budget → BUDGET_STATUS=completed ────────────
@test "SE-217-S2: cmd completing within budget → BUDGET_STATUS=completed" {
  run bash "$SCRIPT" run \
    --budget 10 \
    --cmd "true"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "BUDGET_STATUS: completed"
}

# ── 4. cmd that exceeds budget → BUDGET_STATUS=timeout ──────────────────────
@test "SE-217-S2: cmd exceeding budget → BUDGET_STATUS=timeout" {
  run bash "$SCRIPT" run \
    --budget 1 \
    --cmd "sleep 30"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "BUDGET_STATUS: timeout"
}

# ── 5. cmd with exit != 0 → BUDGET_STATUS=crash ─────────────────────────────
@test "SE-217-S2: cmd with non-zero exit → BUDGET_STATUS=crash" {
  run bash "$SCRIPT" run \
    --budget 10 \
    --cmd "exit 1"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "BUDGET_STATUS: crash"
}

# ── 6. --budget 0 → no timeout, cmd runs to completion ──────────────────────
@test "SE-217-S2: --budget 0 disables timeout, cmd completes" {
  run bash "$SCRIPT" run \
    --budget 0 \
    --cmd "true"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "BUDGET_STATUS: completed"
}

# ── 7. without --score-cmd → SCORE empty but BUDGET_STATUS present ───────────
@test "SE-217-S2: without --score-cmd BUDGET_STATUS present, SCORE line present" {
  run bash "$SCRIPT" run \
    --budget 10 \
    --cmd "true"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "BUDGET_STATUS:"
  echo "$output" | grep -q "SCORE:"
  # SCORE value should be empty (just "SCORE: " with no value after)
  echo "$output" | grep -qE "^SCORE: ?$"
}

# ── 8. --budget negative → error with clear message ─────────────────────────
@test "SE-217-S2: negative --budget produces error" {
  run bash "$SCRIPT" run \
    --budget -5 \
    --cmd "true"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "error"
}

# ── 9. with --run-id and --task → entry created in agent-run-log ─────────────
@test "SE-217-S2: with --run-id and --task entry created in agent-run-log" {
  # Pre-populate a pending entry so keep/discard/crash can update it
  bash "$RUN_LOG" start \
    --run-id "test-run-001" \
    --task "my-task" \
    --hypothesis "test hypothesis"

  run bash "$SCRIPT" run \
    --budget 10 \
    --run-id "test-run-001" \
    --task "my-task" \
    --cmd "true"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "BUDGET_STATUS: completed"

  # Entry should now be in the log with status=keep
  grep -q "test-run-001" "$AGENT_RUN_LOG_FILE"
  grep -q "my-task" "$AGENT_RUN_LOG_FILE"
}

# ── 10. multiple run of same task → separate entries in log ─────────────────
@test "SE-217-S2: multiple runs of same task create separate log entries" {
  # Create two pending entries for the same task under different run IDs
  bash "$RUN_LOG" start \
    --run-id "run-A" \
    --task "shared-task" \
    --hypothesis "first attempt"

  bash "$RUN_LOG" start \
    --run-id "run-B" \
    --task "shared-task" \
    --hypothesis "second attempt"

  bash "$SCRIPT" run \
    --budget 10 \
    --run-id "run-A" \
    --task "shared-task" \
    --cmd "true" > /dev/null

  bash "$SCRIPT" run \
    --budget 10 \
    --run-id "run-B" \
    --task "shared-task" \
    --cmd "true" > /dev/null

  # Both run IDs appear
  grep -q "run-A" "$AGENT_RUN_LOG_FILE"
  grep -q "run-B" "$AGENT_RUN_LOG_FILE"
  # Two entries for shared-task
  local count
  count=$(grep -c "shared-task" "$AGENT_RUN_LOG_FILE")
  [ "$count" -ge 2 ]
}

# ── 11. elapsed_s > 0 for cmd that takes measurable time ────────────────────
@test "SE-217-S2: elapsed_s is numeric and present in output" {
  run bash "$SCRIPT" run \
    --budget 10 \
    --cmd "true"
  [ "$status" -eq 0 ]
  # ELAPSED_S line must be present with a numeric value
  echo "$output" | grep -qE "^ELAPSED_S: [0-9]+"
}

# ── 12. --cmd absent → error with clear message ──────────────────────────────
@test "SE-217-S2: missing --cmd produces error" {
  run bash "$SCRIPT" run \
    --budget 10
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "error"
}
