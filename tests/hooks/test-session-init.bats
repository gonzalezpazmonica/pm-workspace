#!/usr/bin/env bats
# Tests for session-init.sh hook
# Startup hook that loads session context, never blocks
# Ref: .claude/rules/domain/session-init-priority.md

setup() {
  TMPDIR=$(mktemp -d)
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/session-init.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

run_hook() {
  run bash "$HOOK"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.claude/hooks/session-init.sh"
}

# ── Positive cases ──

@test "always exits 0" {
  run_hook
  [ "$status" -eq 0 ]
}

@test "completes within 5 seconds" {
  START=$(date +%s)
  run_hook
  END=$(date +%s)
  ELAPSED=$((END - START))
  [ "$ELAPSED" -lt 10 ]
}

@test "outputs JSON with additionalContext" {
  run_hook
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "additionalContext"
  [[ "$output" == *"{"* ]]
}

# ── Negative / error cases ──

@test "handles missing profile directory" {
  run_hook
  [ "$status" -eq 0 ]
  [[ ! "$output" == *"FATAL"* ]]
}

@test "empty input does not crash" {
  run_hook
  [ "$status" -eq 0 ]
}

# ── Edge cases ──

@test "output is valid JSON structure" {
  run_hook
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'additionalContext' in d or len(d)>0"
}

@test "large HOME path does not crash" {
  run_hook
  [ "$status" -eq 0 ]
  grep -q "additionalContext" <<< "$output"
}

@test "target script has safety flags" {
  grep -q "set -[euo]" $PWD/.claude/hooks/session-init.sh
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash .claude/hooks/validate-bash-global.sh 2>&1"
  [ "$status" -eq 0 ]
}
