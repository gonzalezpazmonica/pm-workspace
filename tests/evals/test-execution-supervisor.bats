#!/usr/bin/env bats
# Tests for SPEC-065 Execution Supervisor + Session Action Log
setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  SCRIPT="scripts/execution-supervisor.sh"
  LOG_SCRIPT="scripts/session-action-log.sh"
  TMPDIR_SUP=$(mktemp -d)
  export SESSION_ACTION_LOG="$TMPDIR_SUP/test-log.jsonl"
  export SESSION_ACTION_SESSION="test-session-$$"
}
teardown() {
  rm -rf "$TMPDIR_SUP"
  unset SESSION_ACTION_LOG SESSION_ACTION_SESSION
}

@test "execution-supervisor.sh exists and is executable" {
  [ -f "$SCRIPT" ] && [ -x "$SCRIPT" ]
}

@test "session-action-log.sh exists and is executable" {
  [ -f "$LOG_SCRIPT" ] && [ -x "$LOG_SCRIPT" ]
}

@test "execution-supervisor.sh has set -uo pipefail" {
  head -5 "$SCRIPT" | grep -q "set -[euo]*o pipefail"
}

@test "session-action-log.sh has set -uo pipefail" {
  head -5 "$LOG_SCRIPT" | grep -q "set -[euo]*o pipefail"
}

@test "log command creates JSONL entry" {
  run bash "$LOG_SCRIPT" log "git-push" "feat/test" "fail" "CI failed"
  [ "$status" -eq 0 ]
  [ -f "$SESSION_ACTION_LOG" ]
  grep -q '"action":"git-push"' "$SESSION_ACTION_LOG"
}
@test "log tracks attempt count for failures" {
  bash "$LOG_SCRIPT" log "pr-plan" "feat/x" "fail" "gate G2 failed" >/dev/null
  bash "$LOG_SCRIPT" log "pr-plan" "feat/x" "fail" "gate G6 failed" >/dev/null
  run bash "$LOG_SCRIPT" attempts "pr-plan" "feat/x"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}
@test "log returns 0 attempts for unknown action" {
  run bash "$LOG_SCRIPT" attempts "nonexistent" "branch"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}
@test "log success entries do not increment attempt count" {
  bash "$LOG_SCRIPT" log "pr-plan" "feat/y" "success" "all gates passed" >/dev/null
  bash "$LOG_SCRIPT" log "pr-plan" "feat/y" "success" "all gates passed" >/dev/null
  run bash "$LOG_SCRIPT" attempts "pr-plan" "feat/y"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}
@test "history shows last entries" {
  bash "$LOG_SCRIPT" log "git-push" "feat/h" "fail" "rejected" >/dev/null
  bash "$LOG_SCRIPT" log "git-push" "feat/h" "success" "pushed" >/dev/null
  run bash "$LOG_SCRIPT" history "git-push"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "rejected"
  echo "$output" | grep -q "pushed"
}
@test "reset clears the log" {
  bash "$LOG_SCRIPT" log "test" "t" "fail" "x" >/dev/null
  [ -f "$SESSION_ACTION_LOG" ]
  run bash "$LOG_SCRIPT" reset
  [ "$status" -eq 0 ]
  [ ! -f "$SESSION_ACTION_LOG" ]
}
@test "details returns failure details for action+target" {
  bash "$LOG_SCRIPT" log "pr-plan" "feat/d" "fail" "G2: dirty tree" >/dev/null
  bash "$LOG_SCRIPT" log "pr-plan" "feat/d" "fail" "G6: BATS failed" >/dev/null
  run bash "$LOG_SCRIPT" details "pr-plan" "feat/d"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "dirty tree"
  echo "$output" | grep -q "BATS failed"
}
@test "supervisor is silent for attempt 1-2" {
  bash "$LOG_SCRIPT" log "pr-plan" "feat/s" "fail" "gate failed" >/dev/null
  bash "$LOG_SCRIPT" log "pr-plan" "feat/s" "fail" "gate failed again" >/dev/null
  run bash "$SCRIPT" "pr-plan" "feat/s" "gate failed again"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
@test "supervisor displays reflection at attempt 3" {
  bash "$LOG_SCRIPT" log "pr-plan" "feat/r" "fail" "G2 dirty" >/dev/null
  bash "$LOG_SCRIPT" log "pr-plan" "feat/r" "fail" "G6 BATS" >/dev/null
  bash "$LOG_SCRIPT" log "pr-plan" "feat/r" "fail" "G6 BATS again" >/dev/null
  run bash "$SCRIPT" "pr-plan" "feat/r" "G6 BATS again" 2>&1
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "SUPERVISOR"
  echo "$output" | grep -q "ROOT CAUSE"
  echo "$output" | grep -q "attempt #3"
}
@test "supervisor shows escalation at attempt 4+" {
  for i in 1 2 3 4; do
    bash "$LOG_SCRIPT" log "push-pr" "feat/e" "fail" "attempt $i" >/dev/null
  done
  run bash "$SCRIPT" "push-pr" "feat/e" "attempt 4" 2>&1
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "ESCALATION"
  echo "$output" | grep -q "redesign"
}
@test "supervisor always exits 0 (advisory)" {
  for i in 1 2 3 4 5; do
    bash "$LOG_SCRIPT" log "test-act" "feat/a" "fail" "fail $i" >/dev/null
  done
  run bash "$SCRIPT" "test-act" "feat/a" "fail 5"
  [ "$status" -eq 0 ]
}
@test "log handles empty detail gracefully" {
  run bash "$LOG_SCRIPT" log "git-push" "feat/empty" "fail" ""
  [ "$status" -eq 0 ]
  grep -q '"action":"git-push"' "$SESSION_ACTION_LOG"
}
@test "log isolates sessions — different session sees 0 attempts" {
  bash "$LOG_SCRIPT" log "pr-plan" "feat/iso" "fail" "fail1" >/dev/null
  bash "$LOG_SCRIPT" log "pr-plan" "feat/iso" "fail" "fail2" >/dev/null
  bash "$LOG_SCRIPT" log "pr-plan" "feat/iso" "fail" "fail3" >/dev/null
  # Change session ID
  export SESSION_ACTION_SESSION="other-session"
  run bash "$LOG_SCRIPT" attempts "pr-plan" "feat/iso"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}
@test "supervisor handles missing log file gracefully" {
  rm -f "$SESSION_ACTION_LOG"
  run bash "$SCRIPT" "pr-plan" "feat/missing" "no log"
  [ "$status" -eq 0 ]
}
@test "log help shows usage" {
  run bash "$LOG_SCRIPT" help
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Usage"
}
@test "history with no log file shows message" {
  rm -f "$SESSION_ACTION_LOG"
  run bash "$LOG_SCRIPT" history
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "No log"
}
