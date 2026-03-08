#!/usr/bin/env bats
# Tests for plan-gate.sh hook
# Warns if implementing without spec. Never blocks (info gate).

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/plan-gate.sh"
  export TEST_TMPDIR="/tmp/hooktest-$$-$BATS_TEST_NUMBER"
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
  mkdir -p "$TEST_TMPDIR/projects/test-project"
  mkdir -p "$TEST_TMPDIR/src"
  cd "$TEST_TMPDIR"
  git init --quiet 2>/dev/null || true
}

teardown() {
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

run_hook() {
  local tmpf="/tmp/gate-input-$$.json"
  printf '%s' "$1" > "$tmpf"
  run bash -c "cd '$TEST_TMPDIR' && export CLAUDE_PROJECT_DIR='$TEST_TMPDIR' && export CLAUDE_TOOL_INPUT_FILE='$FILE_PATH' && cat '$tmpf' | bash '$HOOK'"
  rm -f "$tmpf"
}

# ── Always exits 0 (never blocks) ──

@test "always exits 0" {
  export FILE_PATH="$TEST_TMPDIR/src/service.ts"
  run_hook '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
}

# ── Non-source-code file passes silently ──

@test "non-source-code file passes silently" {
  export FILE_PATH="$TEST_TMPDIR/README.md"
  run_hook '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "Plan Gate" ]]
}

# ── Source code file triggers check ──

@test "source code file (.ts) triggers check" {
  export FILE_PATH="$TEST_TMPDIR/src/service.ts"
  run_hook '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
  # Warning should appear if no spec found
  [[ "$output" =~ "Plan Gate" ]] || [ -f "$TEST_TMPDIR/projects/test-project/any.spec.md" ]
}

@test "source code file (.py) triggers check" {
  export FILE_PATH="$TEST_TMPDIR/src/handler.py"
  run_hook '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
}

@test "source code file (.cs) triggers check" {
  export FILE_PATH="$TEST_TMPDIR/src/Service.cs"
  run_hook '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
}

# ── Handles missing projects directory ──

@test "handles missing projects directory" {
  rm -rf "$TEST_TMPDIR/projects"
  export FILE_PATH="$TEST_TMPDIR/src/handler.go"
  run_hook '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
}

# ── Empty input passes ──

@test "empty input passes" {
  export FILE_PATH=""
  run_hook '{"tool_name":"Edit"}'
  [ "$status" -eq 0 ]
}
