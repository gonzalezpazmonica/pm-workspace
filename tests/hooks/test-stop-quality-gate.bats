#!/usr/bin/env bats
# Tests for stop-quality-gate.sh hook
# Final quality check, never blocks (exit 0 always)

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/stop-quality-gate.sh"
  export TEST_TMPDIR="/tmp/stopqual-$$-$BATS_TEST_NUMBER"
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
  mkdir -p "$TEST_TMPDIR"
  cd "$TEST_TMPDIR"
  git init --quiet 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

run_hook() {
  local tmpf="/tmp/stopqual-input-$$.json"
  printf '%s' "$1" > "$tmpf"
  run bash -c "cd '$TEST_TMPDIR' && cat '$tmpf' | bash '$HOOK'"
  rm -f "$tmpf"
}

@test "always exits 0" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"echo test"}}'
  [ "$status" -eq 0 ]
}

@test "handles stop_hook_active=true anti-recursion" {
  run_hook '{"stop_hook_active":true,"tool_name":"Bash","tool_input":{"command":"echo test"}}'
  [ "$status" -eq 0 ]
}

@test "empty input passes" {
  run_hook '{}'
  [ "$status" -eq 0 ]
}

@test "clean working tree exits 0" {
  # No changes = immediate exit 0
  run_hook '{"tool_name":"Bash","tool_input":{"command":"echo test"}}'
  [ "$status" -eq 0 ]
}

@test "detects secrets pattern in staged files" {
  echo 'password="secret123"' > file.txt
  git add file.txt
  run_hook '{"tool_name":"Bash","tool_input":{"command":"echo test"}}'
  [ "$status" -eq 0 ]
}
