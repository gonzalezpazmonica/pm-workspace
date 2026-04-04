#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-048-dev-session-discard.md
# Tests for dev-session-discard.sh — Clean session cleanup

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/dev-session-discard.sh"
  TMPDIR_DSD=$(mktemp -d)
  export CLAUDE_PROJECT_DIR="$TMPDIR_DSD"
  mkdir -p "$TMPDIR_DSD/.claude/sessions"
  mkdir -p "$TMPDIR_DSD/output/dev-sessions"
}

teardown() {
  rm -rf "$TMPDIR_DSD"
}

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "help shows usage" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage"* ]]
}

@test "no args fails with error" {
  run bash "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"session ID required"* ]]
}

@test "nonexistent session fails" {
  run bash "$SCRIPT" "nonexistent-session"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"not found"* ]]
}

@test "discards session with lock file" {
  echo '{"pid":99999}' > "$TMPDIR_DSD/.claude/sessions/test-session.lock"
  run bash "$SCRIPT" "test-session" "test reason"
  [[ "$status" -eq 0 ]]
  [[ ! -f "$TMPDIR_DSD/.claude/sessions/test-session.lock" ]]
}

@test "discards session with state directory" {
  local state_dir="$TMPDIR_DSD/output/dev-sessions/test-state"
  mkdir -p "$state_dir"
  echo '{"session_id":"test-state","slices":[]}' > "$state_dir/state.json"
  run bash "$SCRIPT" "test-state" "outdated spec"
  [[ "$status" -eq 0 ]]
}

@test "logs discard to discard-log.jsonl" {
  echo '{"pid":99999}' > "$TMPDIR_DSD/.claude/sessions/logged-session.lock"
  bash "$SCRIPT" "logged-session" "testing log"
  local log="$TMPDIR_DSD/output/dev-sessions/discard-log.jsonl"
  [[ -f "$log" ]]
  grep -q "logged-session" "$log"
  grep -q "testing log" "$log"
}

@test "discard reason defaults to manual discard" {
  echo '{"pid":99999}' > "$TMPDIR_DSD/.claude/sessions/default-reason.lock"
  bash "$SCRIPT" "default-reason"
  local log="$TMPDIR_DSD/output/dev-sessions/discard-log.jsonl"
  grep -q "manual discard" "$log"
}

@test "edge: session with both lock and state" {
  echo '{"pid":99999}' > "$TMPDIR_DSD/.claude/sessions/both-session.lock"
  local state_dir="$TMPDIR_DSD/output/dev-sessions/both-session"
  mkdir -p "$state_dir"
  echo '{"session_id":"both-session","slices":[]}' > "$state_dir/state.json"
  run bash "$SCRIPT" "both-session" "cleanup"
  [[ "$status" -eq 0 ]]
  [[ ! -f "$TMPDIR_DSD/.claude/sessions/both-session.lock" ]]
}

@test "edge: special chars in reason" {
  echo '{"pid":99999}' > "$TMPDIR_DSD/.claude/sessions/special.lock"
  run bash "$SCRIPT" "special" "reason with 'quotes' & symbols"
  [[ "$status" -eq 0 ]]
}

@test "coverage: DISCARD_LOG variable defined" {
  grep -q "DISCARD_LOG" "$SCRIPT"
}
