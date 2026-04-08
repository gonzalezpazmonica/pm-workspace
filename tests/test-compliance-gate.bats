#!/usr/bin/env bats
# BATS tests for compliance-gate.sh
# SCRIPT=.claude/hooks/compliance-gate.sh
# SPEC: SPEC-081 — Hook test coverage

SCRIPT=".claude/hooks/compliance-gate.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="standard"
  export TEST_TMPDIR="$TMPDIR/compliance-gate-$$"
  mkdir -p "$TEST_TMPDIR"
  export CLAUDE_PROJECT_DIR="$TEST_TMPDIR"
}

teardown() {
  unset SAVIA_HOOK_PROFILE CLAUDE_PROJECT_DIR CLAUDE_TOOL_INPUT
  rm -rf "$TEST_TMPDIR"
}

@test "script exists and is executable" {
  cd "$BATS_TEST_DIRNAME/.."
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail" {
  cd "$BATS_TEST_DIRNAME/.."
  head -5 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "allow: non-commit command exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT="git status"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "allow: git push exits 0 (not a commit)" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT="git push origin main"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "allow: git diff exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT="git diff HEAD"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "allow: git commit without runner — exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  # No runner.sh exists in TEST_TMPDIR
  export CLAUDE_TOOL_INPUT="git commit -m test"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "allow: git commit with passing runner" {
  cd "$BATS_TEST_DIRNAME/.."
  # Create a runner that passes
  mkdir -p "$TEST_TMPDIR/.claude/compliance"
  cat > "$TEST_TMPDIR/.claude/compliance/runner.sh" << 'RUNNER'
#!/bin/bash
exit 0
RUNNER
  chmod +x "$TEST_TMPDIR/.claude/compliance/runner.sh"
  export CLAUDE_TOOL_INPUT="git commit -m 'feat: add feature'"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "block: git commit with failing runner" {
  cd "$BATS_TEST_DIRNAME/.."
  # Create a runner that fails
  mkdir -p "$TEST_TMPDIR/.claude/compliance"
  cat > "$TEST_TMPDIR/.claude/compliance/runner.sh" << 'RUNNER'
#!/bin/bash
echo "CHANGELOG missing link" >&2
exit 1
RUNNER
  chmod +x "$TEST_TMPDIR/.claude/compliance/runner.sh"
  export CLAUDE_TOOL_INPUT="git commit -m 'feat: add feature'"
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"COMPLIANCE GATE"* ]]
}

@test "block: runner exit code 2 still triggers gate" {
  cd "$BATS_TEST_DIRNAME/.."
  mkdir -p "$TEST_TMPDIR/.claude/compliance"
  cat > "$TEST_TMPDIR/.claude/compliance/runner.sh" << 'RUNNER'
#!/bin/bash
exit 2
RUNNER
  chmod +x "$TEST_TMPDIR/.claude/compliance/runner.sh"
  export CLAUDE_TOOL_INPUT="git commit -m test"
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "skip: minimal profile skips the gate" {
  export SAVIA_HOOK_PROFILE="minimal"
  cd "$BATS_TEST_DIRNAME/.."
  # Even with a failing runner, minimal should skip
  mkdir -p "$TEST_TMPDIR/.claude/compliance"
  cat > "$TEST_TMPDIR/.claude/compliance/runner.sh" << 'RUNNER'
#!/bin/bash
exit 1
RUNNER
  chmod +x "$TEST_TMPDIR/.claude/compliance/runner.sh"
  export CLAUDE_TOOL_INPUT="git commit -m test"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "allow: empty CLAUDE_TOOL_INPUT exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT=""
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "coverage: checks for git commit in input" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -q "git commit" "$SCRIPT"
}

@test "coverage: references runner.sh path" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -q "runner.sh" "$SCRIPT"
}
