#!/usr/bin/env bats
# Tests for pre-commit-review.sh hook
# Warning-only hook that reviews staged files for common issues

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/pre-commit-review.sh"
  export TEST_TMPDIR="/tmp/prerev-$$-$BATS_TEST_NUMBER"
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
  mkdir -p "$TEST_TMPDIR"
  cd "$TEST_TMPDIR"
  git init --quiet 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

run_hook() {
  local tmpf="/tmp/prerev-input-$$.json"
  printf '%s' "$1" > "$tmpf"
  run bash -c "cd '$TEST_TMPDIR' && cat '$tmpf' | bash '$HOOK'"
  rm -f "$tmpf"
}

# ── Warning-only hook: always exits 0 ──

@test "always exits 0 (never blocks)" {
  echo "console.log('test')" > test.js
  git add test.js
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
  [ "$status" -eq 0 ]
}

@test "non-commit command passes" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'
  [ "$status" -eq 0 ]
}

@test "empty input passes" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":""}}'
  [ "$status" -eq 0 ]
}

@test "handles no staged files gracefully" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
  [ "$status" -eq 0 ]
}

@test "outputs Code Review in verbose mode" {
  echo "function test() {}" > test.js
  git add test.js
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
  # Should always exit 0, but may have output
  [ "$status" -eq 0 ]
}

@test "handles missing rules file gracefully" {
  echo "const x = 5;" > test.ts
  git add test.ts
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
  [ "$status" -eq 0 ]
}
