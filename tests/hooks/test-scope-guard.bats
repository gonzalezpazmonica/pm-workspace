#!/usr/bin/env bats
# Tests for scope-guard.sh hook
# Warning-only hook that checks file modifications against spec scope

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/scope-guard.sh"
  export TEST_TMPDIR="/tmp/scopeguard-$$-$BATS_TEST_NUMBER"
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
  mkdir -p "$TEST_TMPDIR"
  cd "$TEST_TMPDIR"
  git init --quiet 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

run_hook() {
  local tmpf="/tmp/scopeguard-input-$$.json"
  printf '%s' "$1" > "$tmpf"
  run bash -c "cd '$TEST_TMPDIR' && cat '$tmpf' | bash '$HOOK'"
  rm -f "$tmpf"
}

# ── Warning-only hook: always exits 0 ──

@test "always exits 0 (never blocks)" {
  echo "content" > file.txt
  git add file.txt
  run_hook '{"tool_name":"Edit","tool_input":{"file_path":"file.txt","old_string":"a","new_string":"b"}}'
  [ "$status" -eq 0 ]
}

@test "empty input passes" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":""}}'
  [ "$status" -eq 0 ]
}

@test "non-edit tool passes" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
  [ "$status" -eq 0 ]
}

@test "handles no spec files gracefully" {
  echo "content" > file.py
  git add file.py
  run_hook '{"tool_name":"Edit","tool_input":{"file_path":"file.py","old_string":"a","new_string":"b"}}'
  [ "$status" -eq 0 ]
}

@test "handles no git repo gracefully" {
  rm -rf "$TEST_TMPDIR/.git"
  echo "content" > file.txt
  run_hook '{"tool_name":"Edit","tool_input":{"file_path":"file.txt","old_string":"a","new_string":"b"}}'
  [ "$status" -eq 0 ]
}
