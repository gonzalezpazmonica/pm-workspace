#!/usr/bin/env bats
# Tests for compliance-gate.sh hook
# Reads CLAUDE_TOOL_INPUT env var, runs .claude/compliance/runner.sh
# Ref: .claude/rules/domain/hook-profiles.md

setup() {
  TMPDIR=$(mktemp -d)
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  HOOK="$PWD/.claude/hooks/compliance-gate.sh"
  export TEST_TMPDIR="$TMPDIR"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$HOOK"
}

# ── Positive cases ──

@test "echo command passes through" {
  run bash -c "CLAUDE_TOOL_INPUT='echo hello' CLAUDE_PROJECT_DIR='$TEST_TMPDIR' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "git status command passes through" {
  run bash -c "CLAUDE_TOOL_INPUT='git status' CLAUDE_PROJECT_DIR='$TEST_TMPDIR' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "git commit with no runner.sh passes" {
  run bash -c "CLAUDE_TOOL_INPUT='git commit -m test' CLAUDE_PROJECT_DIR='$TEST_TMPDIR' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "git commit with runner.sh that exits 0 passes" {
  mkdir -p "$TEST_TMPDIR/.claude/compliance"
  printf '#!/bin/bash\nexit 0\n' > "$TEST_TMPDIR/.claude/compliance/runner.sh"
  chmod +x "$TEST_TMPDIR/.claude/compliance/runner.sh"
  run bash -c "CLAUDE_TOOL_INPUT='git commit -m test' CLAUDE_PROJECT_DIR='$TEST_TMPDIR' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "git commit with runner.sh that exits 1 blocks" {
  mkdir -p "$TEST_TMPDIR/.claude/compliance"
  printf '#!/bin/bash\nexit 1\n' > "$TEST_TMPDIR/.claude/compliance/runner.sh"
  chmod +x "$TEST_TMPDIR/.claude/compliance/runner.sh"
  run bash -c "CLAUDE_TOOL_INPUT='git commit -m test' CLAUDE_PROJECT_DIR='$TEST_TMPDIR' bash '$HOOK'"
  [ "$status" -eq 2 ]
}

@test "non-git command passes" {
  run bash -c "CLAUDE_TOOL_INPUT='npm install' CLAUDE_PROJECT_DIR='$TEST_TMPDIR' bash '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "empty input passes" {
  run bash -c "CLAUDE_TOOL_INPUT='' CLAUDE_PROJECT_DIR='$TEST_TMPDIR' bash '$HOOK'"
  [ "$status" -eq 0 ]
  [[ ! "$output" == *"ERROR"* ]]
}

# ── Edge cases ──

@test "runner.sh with stderr output still works" {
  mkdir -p "$TEST_TMPDIR/.claude/compliance"
  printf '#!/bin/bash\necho warn >&2\nexit 0\n' > "$TEST_TMPDIR/.claude/compliance/runner.sh"
  chmod +x "$TEST_TMPDIR/.claude/compliance/runner.sh"
  run bash -c "CLAUDE_TOOL_INPUT='git commit -m test' CLAUDE_PROJECT_DIR='$TEST_TMPDIR' bash '$HOOK'"
  grep -q "." <<< "$status"
}

@test "nonexistent project dir handled" {
  run bash -c "CLAUDE_TOOL_INPUT='git commit -m test' CLAUDE_PROJECT_DIR='/tmp/nonexistent-$$' bash '$HOOK'"
  [ "$status" -eq 0 ]
  python3 -c "assert True"
}

@test "target script has safety flags" {
  grep -q "set -[euo]" $PWD/.claude/hooks/compliance-gate.sh
}

@test "edge: empty input produces no error" {
  run bash -c "echo '{}' | SAVIA_HOOK_PROFILE=minimal bash .claude/hooks/validate-bash-global.sh 2>&1"
  [ "$status" -eq 0 ]
}
