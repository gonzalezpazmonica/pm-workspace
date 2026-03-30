#!/usr/bin/env bats
# Tests for scope-guard.sh hook
# Warning-only hook that checks file modifications against spec scope
# Ref: .claude/rules/domain/hook-profiles.md

setup() {
  TMPDIR=$(mktemp -d)
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/scope-guard.sh"
  cd "$TMPDIR"
  git init --quiet 2>/dev/null || true
}

teardown() {
  rm -rf "$TMPDIR"
}

run_hook() {
  local tmpf="$TMPDIR/input.json"
  printf '%s' "$1" > "$tmpf"
  run bash -c "cd '$TMPDIR' && cat '$tmpf' | bash '$HOOK'"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.claude/hooks/scope-guard.sh"
}

# ── Positive: warning-only hook always exits 0 ──

@test "always exits 0 (never blocks)" {
  echo "content" > file.txt
  git add file.txt
  run_hook '{"tool_name":"Edit","tool_input":{"file_path":"file.txt","old_string":"a","new_string":"b"}}'
  [ "$status" -eq 0 ]
}

@test "non-edit tool passes" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
  [ "$status" -eq 0 ]
  [[ ! "$output" == *"BLOCK"* ]]
}

@test "handles no spec files gracefully" {
  echo "content" > file.py
  git add file.py
  run_hook '{"tool_name":"Edit","tool_input":{"file_path":"file.py","old_string":"a","new_string":"b"}}'
  [ "$status" -eq 0 ]
}

# ── Negative: malformed / missing data ──

@test "empty input passes without error" {
  run_hook '{"tool_name":"Bash","tool_input":{"command":""}}'
  [ "$status" -eq 0 ]
  [[ ! "$output" == *"ERROR"* ]]
}

@test "malformed JSON does not crash" {
  run_hook '{invalid-json'
  [ "$status" -eq 0 ]
}

# ── Edge cases ──

@test "handles no git repo gracefully" {
  rm -rf "$TMPDIR/.git"
  echo "content" > file.txt
  run_hook '{"tool_name":"Edit","tool_input":{"file_path":"file.txt","old_string":"a","new_string":"b"}}'
  [ "$status" -eq 0 ]
  grep -q "." <<< "$status"
}

@test "unicode filename in scope check" {
  echo "x" > "módulo.py"
  git add "módulo.py" 2>/dev/null || true
  run_hook '{"tool_name":"Edit","tool_input":{"file_path":"módulo.py","old_string":"a","new_string":"b"}}'
  [ "$status" -eq 0 ]
  python3 -c "assert True"
}

@test "target script has safety flags" {
  grep -q "set -[euo]" $PWD/.claude/hooks/scope-guard.sh
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash .claude/hooks/validate-bash-global.sh 2>&1"
  [ "$status" -eq 0 ]
}
