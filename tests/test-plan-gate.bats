#!/usr/bin/env bats
# BATS tests for plan-gate.sh
# SCRIPT=.claude/hooks/plan-gate.sh
# SPEC: SPEC-081 — Hook test coverage

SCRIPT=".claude/hooks/plan-gate.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="standard"
  export TEST_TMPDIR="$TMPDIR/plan-gate-$$"
  mkdir -p "$TEST_TMPDIR"
  export CLAUDE_PROJECT_DIR="$TEST_TMPDIR"
}

teardown() {
  unset SAVIA_HOOK_PROFILE CLAUDE_PROJECT_DIR CLAUDE_TOOL_INPUT_FILE
  rm -rf "$TEST_TMPDIR"
}

@test "script exists and is executable" {
  cd "$BATS_TEST_DIRNAME/.."
  [[ -x "$SCRIPT" ]]
}

@test "script has set -uo pipefail" {
  cd "$BATS_TEST_DIRNAME/.."
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "allow: non-code file exits 0 silently" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT_FILE="docs/notes.md"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "allow: no FILE set exits 0" {
  cd "$BATS_TEST_DIRNAME/.."
  unset CLAUDE_TOOL_INPUT_FILE
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "allow: .json file exits 0 silently" {
  cd "$BATS_TEST_DIRNAME/.."
  export CLAUDE_TOOL_INPUT_FILE="config/settings.json"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "warning: .cs file without spec shows warning" {
  cd "$BATS_TEST_DIRNAME/.."
  # Create projects dir but no specs
  mkdir -p "$TEST_TMPDIR/projects"
  export CLAUDE_TOOL_INPUT_FILE="src/Service.cs"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Plan Gate"* ]]
}

@test "allow: .ts file with recent spec present — no warning" {
  cd "$BATS_TEST_DIRNAME/.."
  mkdir -p "$TEST_TMPDIR/projects/alpha/specs"
  touch "$TEST_TMPDIR/projects/alpha/specs/feature.spec.md"
  export CLAUDE_TOOL_INPUT_FILE="src/service.ts"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  # Should NOT contain warning since spec exists
  [[ "$output" != *"Plan Gate"* ]]
}

@test "allow: no projects directory — skip silently" {
  cd "$BATS_TEST_DIRNAME/.."
  # TEST_TMPDIR has no projects/ dir
  export CLAUDE_TOOL_INPUT_FILE="src/handler.py"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "never blocks: always exits 0 even with warning" {
  cd "$BATS_TEST_DIRNAME/.."
  mkdir -p "$TEST_TMPDIR/projects"
  export CLAUDE_TOOL_INPUT_FILE="src/main.go"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "skip: minimal profile skips the gate" {
  export SAVIA_HOOK_PROFILE="minimal"
  cd "$BATS_TEST_DIRNAME/.."
  mkdir -p "$TEST_TMPDIR/projects"
  export CLAUDE_TOOL_INPUT_FILE="src/Service.cs"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  # In minimal, the hook should skip entirely (no warning)
  [[ "$output" != *"Plan Gate"* ]]
}

@test "allow: .py file triggers check" {
  cd "$BATS_TEST_DIRNAME/.."
  mkdir -p "$TEST_TMPDIR/projects"
  export CLAUDE_TOOL_INPUT_FILE="app/views.py"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Plan Gate"* ]]
}

@test "allow: .java file triggers check" {
  cd "$BATS_TEST_DIRNAME/.."
  mkdir -p "$TEST_TMPDIR/projects"
  export CLAUDE_TOOL_INPUT_FILE="src/Main.java"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Plan Gate"* ]]
}

@test "coverage: uses find for spec search" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -q "find" "$SCRIPT"
}

@test "coverage: references CLAUDE_TOOL_INPUT_FILE" {
  cd "$BATS_TEST_DIRNAME/.."
  grep -q "CLAUDE_TOOL_INPUT_FILE" "$SCRIPT"
}
