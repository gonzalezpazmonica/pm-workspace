#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-065-execution-supervisor.md
# Tests for execution-supervisor.sh — Advisory reflection trigger

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/execution-supervisor.sh"
  export LOG_SCRIPT="$REPO_ROOT/scripts/session-action-log.sh"
  TMPDIR_ES=$(mktemp -d)
  export SESSION_ACTION_LOG="$TMPDIR_ES/action-log.jsonl"
  export SESSION_ACTION_SESSION="test-$$"
}

teardown() {
  rm -rf "$TMPDIR_ES"
}

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "always exits 0 (advisory)" {
  run bash "$SCRIPT" "push" "feat/x" "error"
  [[ "$status" -eq 0 ]]
}

@test "silent on attempt 1" {
  bash "$LOG_SCRIPT" log "push" "feat/a" "fail" "err1" >/dev/null
  run bash "$SCRIPT" "push" "feat/a" "err1"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "silent on attempt 2" {
  bash "$LOG_SCRIPT" log "push" "feat/b" "fail" "err1" >/dev/null
  bash "$LOG_SCRIPT" log "push" "feat/b" "fail" "err2" >/dev/null
  run bash "$SCRIPT" "push" "feat/b" "err2"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "shows reflection prompt on attempt 3+" {
  bash "$LOG_SCRIPT" log "push" "feat/c" "fail" "err1" >/dev/null
  bash "$LOG_SCRIPT" log "push" "feat/c" "fail" "err2" >/dev/null
  bash "$LOG_SCRIPT" log "push" "feat/c" "fail" "err3" >/dev/null
  # Supervisor writes to stderr, capture both
  output_combined=$(bash "$SCRIPT" "push" "feat/c" "err3" 2>&1)
  [[ "$output_combined" == *"SUPERVISOR"* ]]
  [[ "$output_combined" == *"ROOT CAUSE"* ]]
}

@test "shows escalation on attempt 4+" {
  bash "$LOG_SCRIPT" log "ci" "feat/d" "fail" "e1" >/dev/null
  bash "$LOG_SCRIPT" log "ci" "feat/d" "fail" "e2" >/dev/null
  bash "$LOG_SCRIPT" log "ci" "feat/d" "fail" "e3" >/dev/null
  bash "$LOG_SCRIPT" log "ci" "feat/d" "fail" "e4" >/dev/null
  output_combined=$(bash "$SCRIPT" "ci" "feat/d" "e4" 2>&1)
  [[ "$output_combined" == *"ESCALATION"* ]]
  [[ "$output_combined" == *"redesign"* ]]
}

@test "exit 0 even at attempt 5" {
  for i in 1 2 3 4 5; do
    bash "$LOG_SCRIPT" log "deploy" "prod" "fail" "e$i" >/dev/null
  done
  run bash "$SCRIPT" "deploy" "prod" "e5"
  [[ "$status" -eq 0 ]]
}

@test "no output on success path (0 attempts)" {
  run bash "$SCRIPT" "new-action" "new-target" "detail"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "edge: special chars in target handled" {
  bash "$LOG_SCRIPT" log "push" "feat/special-chars" "fail" "err with spaces & symbols" >/dev/null
  run bash "$SCRIPT" "push" "feat/special-chars" "err"
  [[ "$status" -eq 0 ]]
}

@test "coverage: script references session-action-log" {
  grep -q "session-action-log" "$SCRIPT"
}

@test "negative: missing log script does not crash" {
  local save_path="$PATH"
  export SESSION_ACTION_LOG="/nonexistent/path/log.jsonl"
  run bash "$SCRIPT" "push" "feat/x" "error"
  [[ "$status" -eq 0 ]]
}

@test "negative: empty action still exits 0" {
  run bash "$SCRIPT" "" "" ""
  [[ "$status" -eq 0 ]]
}

@test "edge: very long detail string" {
  local long_detail
  long_detail=$(printf 'X%.0s' {1..500})
  bash "$LOG_SCRIPT" log "push" "feat/long" "fail" "$long_detail" >/dev/null
  run bash "$SCRIPT" "push" "feat/long" "$long_detail"
  [[ "$status" -eq 0 ]]
}

@test "edge: reflection prompt mentions ROOT CAUSE" {
  for i in 1 2 3; do
    bash "$LOG_SCRIPT" log "ci" "feat/root" "fail" "err$i" >/dev/null
  done
  local combined
  combined=$(bash "$SCRIPT" "ci" "feat/root" "err3" 2>&1)
  [[ "$combined" == *"ROOT CAUSE"* ]]
  [[ "$combined" == *"senior engineer"* ]]
}
