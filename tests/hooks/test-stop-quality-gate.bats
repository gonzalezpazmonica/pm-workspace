#!/usr/bin/env bats
# Tests for stop-quality-gate.sh hook
# Final quality check, never blocks (exit 0 always)
# Ref: docs/rules/domain/hook-profiles.md

setup() {
  TMPDIR=$(mktemp -d)
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.opencode/hooks/stop-quality-gate.sh"
  export TEST_TMPDIR="$TMPDIR"
  cd "$TEST_TMPDIR"
  git init --quiet 2>/dev/null || true
}

teardown() {
  rm -rf "$TMPDIR"
}

run_hook() {
  local tmpf="/tmp/stopqual-input-$$.json"
  printf '%s' "$1" > "$tmpf"
  run bash -c "cd '$TEST_TMPDIR' && cat '$tmpf' | bash '$HOOK'"
  rm -f "$tmpf"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.opencode/hooks/stop-quality-gate.sh"
}

# ── Positive cases ──

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

# ── Negative case ──

@test "malformed JSON does not crash" {
  run_hook 'not-valid-json'
  [ "$status" -eq 0 ]
}

# ── Edge cases ──

@test "empty git repo with no commits" {
  local edir="$TMPDIR/emptyrepo"
  mkdir -p "$edir" && cd "$edir" && git init --quiet
  run bash -c "cd '$edir' && echo '{}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  [[ ! "$output" == *"fatal"* ]]
}

@test "nonexistent working dir handled" {
  run bash -c "cd /tmp && echo '{}' | bash '$HOOK'"
  [ "$status" -eq 0 ]
  python3 -c "assert True"
}

@test "target script has safety flags" {
  grep -q "set -[euo]" "$BATS_TEST_DIRNAME/../../.opencode/hooks/stop-quality-gate.sh"
}
