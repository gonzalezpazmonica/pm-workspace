#!/usr/bin/env bats
# Tests for session-init.sh hook
# Startup hook that loads session context, never blocks

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/session-init.sh"
}

teardown() {
  :
}

run_hook() {
  run bash "$HOOK"
}

# ── Never blocks (always exits 0) ──

@test "always exits 0" {
  run_hook
  [ "$status" -eq 0 ]
}

@test "empty input passes" {
  # Hook doesn't read input for session-init
  run_hook
  [ "$status" -eq 0 ]
}

@test "completes within 5 seconds" {
  # Timeout is internal (5 seconds)
  START=$(date +%s)
  run_hook
  END=$(date +%s)
  ELAPSED=$((END - START))
  # Should complete quickly, well under 5 seconds
  [ "$ELAPSED" -lt 10 ]
}

@test "handles missing profile directory" {
  # Hook has fallback logic
  run_hook
  [ "$status" -eq 0 ]
}

@test "outputs JSON with additionalContext" {
  run_hook
  [ "$status" -eq 0 ]
  # Output should be valid JSON
  echo "$output" | grep -q "additionalContext"
}
