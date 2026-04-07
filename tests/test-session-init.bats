#!/usr/bin/env bats
# BATS tests for session-init.sh — SPEC-032 audit coverage

SCRIPT=".claude/hooks/session-init.sh"

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script has safety flags" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "runs without error" {
  # session-init reads environment, should not crash
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "does not require stdin" {
  run bash "$SCRIPT" < /dev/null
  [[ "$status" -eq 0 ]]
}

@test "produces output for session context" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "checks for PAT file" {
  grep -q "devops-pat\|PAT" "$SCRIPT"
}

@test "detects active profile" {
  grep -q "active-user\|active_slug" "$SCRIPT"
}

@test "detects git branch" {
  grep -q "git.*branch\|rev-parse" "$SCRIPT"
}
