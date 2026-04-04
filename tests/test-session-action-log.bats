#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-065-execution-supervisor.md
# Tests for session-action-log.sh — Append-only session action log

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/session-action-log.sh"
  TMPDIR_SAL=$(mktemp -d)
  export SESSION_ACTION_LOG="$TMPDIR_SAL/action-log.jsonl"
  export SESSION_ACTION_SESSION="test-$$"
}

teardown() {
  rm -rf "$TMPDIR_SAL"
}

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "help shows usage" {
  run bash "$SCRIPT" help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"session-action-log"* ]]
}

@test "log requires action, target, result" {
  run bash "$SCRIPT" log
  [[ "$status" -ne 0 ]]
}

@test "log appends entry and returns attempt number" {
  run bash "$SCRIPT" log "git-push" "feat/x" "fail" "CI failed"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "1" ]]
  [[ -f "$SESSION_ACTION_LOG" ]]
  grep -q "git-push" "$SESSION_ACTION_LOG"
}

@test "attempts returns 0 for unknown action" {
  run bash "$SCRIPT" attempts "nonexistent" "target"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "0" ]]
}

@test "attempts increments correctly" {
  bash "$SCRIPT" log "push" "feat/y" "fail" "error1" >/dev/null
  bash "$SCRIPT" log "push" "feat/y" "fail" "error2" >/dev/null
  run bash "$SCRIPT" attempts "push" "feat/y"
  [[ "$output" == "2" ]]
}

@test "log entry contains valid JSON fields" {
  bash "$SCRIPT" log "pr-plan" "feat/z" "fail" "gate 3 blocked" >/dev/null
  local line
  line=$(tail -1 "$SESSION_ACTION_LOG")
  [[ "$line" == *'"action":"pr-plan"'* ]]
  [[ "$line" == *'"target":"feat/z"'* ]]
  [[ "$line" == *'"result":"fail"'* ]]
  [[ "$line" == *'"attempt":1'* ]]
}

@test "history shows entries for action type" {
  bash "$SCRIPT" log "git-push" "feat/a" "fail" "err" >/dev/null
  bash "$SCRIPT" log "git-push" "feat/b" "ok" "done" >/dev/null
  run bash "$SCRIPT" history "git-push"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"feat/a"* ]]
  [[ "$output" == *"feat/b"* ]]
}

@test "reset clears log" {
  bash "$SCRIPT" log "x" "y" "fail" "z" >/dev/null
  run bash "$SCRIPT" reset
  [[ "$status" -eq 0 ]]
  [[ ! -s "$SESSION_ACTION_LOG" ]]
}

@test "different sessions are isolated" {
  export SESSION_ACTION_SESSION="session-A"
  bash "$SCRIPT" log "push" "feat/x" "fail" "err" >/dev/null
  export SESSION_ACTION_SESSION="session-B"
  run bash "$SCRIPT" attempts "push" "feat/x"
  [[ "$output" == "0" ]]
}

@test "unknown command fails or shows help" {
  run bash "$SCRIPT" bogus
  [[ "$status" -ne 0 ]] || [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "edge: empty detail is acceptable" {
  run bash "$SCRIPT" log "push" "main" "ok" ""
  [[ "$status" -eq 0 ]]
}
