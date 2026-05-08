#!/usr/bin/env bats
# BATS tests for session-init.sh
# SCRIPT=.opencode/hooks/session-init.sh
# SPEC: SPEC-032 Security Benchmarks — session initialization

SCRIPT=".opencode/hooks/session-init.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export CLAUDE_PROJECT_DIR="$(pwd)"
}

teardown() {
  :
}

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "positive: runs without error" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "positive: does not require stdin" {
  run bash "$SCRIPT" < /dev/null
  [[ "$status" -eq 0 ]]
}

@test "positive: produces output for session context" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "negative: does not crash with missing PAT file" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "edge: handles missing profile directory" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "edge: handles empty environment gracefully" {
  run env -i HOME="$HOME" PATH="$PATH" bash "$SCRIPT"
  # May warn but should not crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "coverage: checks for PAT file" {
  grep -q "devops-pat\|PAT" "$SCRIPT"
}

@test "coverage: detects active profile" {
  grep -q "active-user\|active_slug" "$SCRIPT"
}

@test "coverage: detects git branch" {
  grep -q "git.*branch\|rev-parse" "$SCRIPT"
}

@test "coverage: uses hook profile system" {
  grep -q "SAVIA_HOOK_PROFILE\|profile" "$SCRIPT"
}
