#!/usr/bin/env bats
# Tests for SPEC-051 Session State Machine — Phase 1

setup() {
  SCRIPT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/scripts/session-state-machine.sh"
  export TEST_TMPDIR="/tmp/ssm-$$-$BATS_TEST_NUMBER"
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
  mkdir -p "$TEST_TMPDIR"
  export SESSIONS_DIR="$TEST_TMPDIR/sessions"
}

teardown() {
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

@test "script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "script uses set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -[euo]*o pipefail"
}

@test "init creates session with spawning state" {
  run bash "$SCRIPT" --session-id test-001 --init
  [ "$status" -eq 0 ]
  [[ "$output" =~ "OK" ]]
  [[ "$output" =~ "spawning" ]]
  # Verify state file
  run python3 -c "import json; print(json.load(open('$SESSIONS_DIR/test-001/state.json'))['status'])"
  [ "$output" = "spawning" ]
}

@test "valid transition succeeds (spawning -> context-loading)" {
  bash "$SCRIPT" --session-id test-002 --init
  run bash "$SCRIPT" --session-id test-002 --transition context-loading
  [ "$status" -eq 0 ]
  [[ "$output" =~ "OK: spawning -> context-loading" ]]
}

@test "invalid transition is blocked" {
  bash "$SCRIPT" --session-id test-003 --init
  run bash "$SCRIPT" --session-id test-003 --transition merged
  [ "$status" -ne 0 ]
  [[ "$output" =~ "ERROR" ]]
  [[ "$output" =~ "invalid transition" ]]
}

@test "status returns current state" {
  bash "$SCRIPT" --session-id test-004 --init
  bash "$SCRIPT" --session-id test-004 --transition context-loading
  run bash "$SCRIPT" --session-id test-004 --status
  [ "$status" -eq 0 ]
  [ "$output" = "context-loading" ]
}

@test "happy path: spawning through verified" {
  bash "$SCRIPT" --session-id test-005 --init
  bash "$SCRIPT" --session-id test-005 --transition context-loading
  bash "$SCRIPT" --session-id test-005 --transition implementing
  bash "$SCRIPT" --session-id test-005 --transition validating
  run bash "$SCRIPT" --session-id test-005 --transition verified
  [ "$status" -eq 0 ]
  [[ "$output" =~ "OK: validating -> verified" ]]
  run bash "$SCRIPT" --session-id test-005 --status
  [ "$output" = "verified" ]
}

@test "terminal state blocks further transitions" {
  bash "$SCRIPT" --session-id test-006 --init
  bash "$SCRIPT" --session-id test-006 --transition discarded
  run bash -c "SESSIONS_DIR='$SESSIONS_DIR' bash '$SCRIPT' --session-id test-006 --transition implementing 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "ERROR" ]]
  [[ "$output" =~ "invalid transition" ]]
}

@test "trace events are emitted to transitions.jsonl" {
  bash "$SCRIPT" --session-id test-007 --init
  bash "$SCRIPT" --session-id test-007 --transition context-loading
  TRACE="$SESSIONS_DIR/test-007/transitions.jsonl"
  [ -f "$TRACE" ]
  line_count=$(wc -l < "$TRACE")
  [ "$line_count" -ge 2 ]
  run python3 -c "import json; e=json.loads(open('$TRACE').readlines()[-1]); print(e['to'])"
  [ "$output" = "context-loading" ]
}

@test "edge: nonexistent session returns error on status" {
  run bash "$SCRIPT" --session-id nonexistent-999 --status
  [ "$status" -ne 0 ]
  [[ "$output" =~ "ERROR" ]]
}

@test "SPEC-051 doc exists" {
  [ -f "$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/docs/propuestas/SPEC-051-session-state-machine.md" ]
}
