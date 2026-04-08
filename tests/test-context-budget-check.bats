#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-086-proactive-context-budget.md
# Tests for context-budget-check.sh — Proactive context budget tracker

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/context-budget-check.sh"
  TMPDIR_CB=$(mktemp -d)
  export HOME="$TMPDIR_CB"
  unset CLAUDE_CONTEXT_USAGE_PCT
  unset CONTEXT_BUDGET_THRESHOLD_STANDARD
  unset CONTEXT_BUDGET_THRESHOLD_EMERGENCY
  unset CONTEXT_BUDGET_MAX_FAILURES
}

teardown() {
  rm -rf "$TMPDIR_CB"
}

@test "script has safety flags" {
  head -15 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "below 80%: NO_ACTION" {
  run bash "$SCRIPT" 50
  [[ "$status" -eq 0 ]]
  [[ "$output" == "NO_ACTION" ]]
}

@test "at 79%: NO_ACTION" {
  run bash "$SCRIPT" 79
  [[ "$status" -eq 0 ]]
  [[ "$output" == "NO_ACTION" ]]
}

@test "at 80%: STANDARD_COMPACT" {
  run bash "$SCRIPT" 80
  [[ "$status" -eq 1 ]]
  [[ "$output" == "STANDARD_COMPACT" ]]
}

@test "at 90%: STANDARD_COMPACT" {
  run bash "$SCRIPT" 90
  [[ "$status" -eq 1 ]]
  [[ "$output" == "STANDARD_COMPACT" ]]
}

@test "at 95%: EMERGENCY_COMPACT" {
  run bash "$SCRIPT" 95
  [[ "$status" -eq 2 ]]
  [[ "$output" == "EMERGENCY_COMPACT" ]]
}

@test "at 100%: EMERGENCY_COMPACT" {
  run bash "$SCRIPT" 100
  [[ "$status" -eq 2 ]]
  [[ "$output" == "EMERGENCY_COMPACT" ]]
}

@test "circuit breaker after 3 failures: CIRCUIT_OPEN" {
  mkdir -p "$TMPDIR_CB/.savia"
  # Simulate 3 consecutive failures
  echo "3" > "$TMPDIR_CB/.savia/compact-failures"
  run bash "$SCRIPT" 85
  [[ "$status" -eq 3 ]]
  [[ "$output" == "CIRCUIT_OPEN" ]]
}

@test "circuit breaker at emergency threshold: CIRCUIT_OPEN" {
  mkdir -p "$TMPDIR_CB/.savia"
  echo "3" > "$TMPDIR_CB/.savia/compact-failures"
  run bash "$SCRIPT" 97
  [[ "$status" -eq 3 ]]
  [[ "$output" == "CIRCUIT_OPEN" ]]
}

@test "reset failures when below threshold" {
  mkdir -p "$TMPDIR_CB/.savia"
  echo "2" > "$TMPDIR_CB/.savia/compact-failures"
  run bash "$SCRIPT" 50
  [[ "$status" -eq 0 ]]
  [[ "$output" == "NO_ACTION" ]]
  # Failure file should be removed after reset
  [[ ! -f "$TMPDIR_CB/.savia/compact-failures" ]]
}

@test "failure count increments on standard compact" {
  run bash "$SCRIPT" 85
  [[ "$status" -eq 1 ]]
  [[ "$(cat "$TMPDIR_CB/.savia/compact-failures")" == "1" ]]
  # Second call
  run bash "$SCRIPT" 85
  [[ "$(cat "$TMPDIR_CB/.savia/compact-failures")" == "2" ]]
}

@test "env var CLAUDE_CONTEXT_USAGE_PCT used as fallback" {
  export CLAUDE_CONTEXT_USAGE_PCT=92
  run bash "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == "STANDARD_COMPACT" ]]
}

@test "argument takes priority over env var" {
  export CLAUDE_CONTEXT_USAGE_PCT=95
  run bash "$SCRIPT" 50
  [[ "$status" -eq 0 ]]
  [[ "$output" == "NO_ACTION" ]]
}

@test "missing env var and no argument: NO_ACTION graceful fallback" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "NO_ACTION" ]]
}

@test "non-numeric input: NO_ACTION graceful fallback" {
  run bash "$SCRIPT" "abc"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "NO_ACTION" ]]
}

@test "zero percent: NO_ACTION" {
  run bash "$SCRIPT" 0
  [[ "$status" -eq 0 ]]
  [[ "$output" == "NO_ACTION" ]]
}

@test "custom thresholds via env vars" {
  export CONTEXT_BUDGET_THRESHOLD_STANDARD=60
  export CONTEXT_BUDGET_THRESHOLD_EMERGENCY=90
  run bash "$SCRIPT" 65
  [[ "$status" -eq 1 ]]
  [[ "$output" == "STANDARD_COMPACT" ]]
}

@test "custom max failures via env var" {
  export CONTEXT_BUDGET_MAX_FAILURES=1
  # First call: increment to 1
  bash "$SCRIPT" 85 || true
  # Second call: circuit should be open (1 >= 1)
  run bash "$SCRIPT" 85
  [[ "$status" -eq 3 ]]
  [[ "$output" == "CIRCUIT_OPEN" ]]
}
