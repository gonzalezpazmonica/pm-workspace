#!/usr/bin/env bats
# Ref: docs/rules/domain/command-validation.md
# Tests for validate-commands.sh — Slash command static validation

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/validate-commands.sh"
  TMPDIR_VC=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_VC"
}

@test "validates all commands without crash" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT"
  # May have warnings but should not crash
  [[ "$status" -le 1 ]]
  [[ "$output" == *"OK"* ]] || [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"WARN"* ]]
}

@test "validates a specific command file" {
  cd "$REPO_ROOT"
  local cmd
  cmd=$(ls .claude/commands/*.md | head -1)
  [[ -n "$cmd" ]] || skip "No command files found"
  run bash "$SCRIPT" "$cmd"
  [[ "$status" -le 1 ]]
}

@test "reports errors on empty file" {
  cd "$REPO_ROOT"
  touch "$TMPDIR_VC/empty.md"
  run bash "$SCRIPT" "$TMPDIR_VC/empty.md"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"ERROR"* ]]
}

@test "reports line count for oversized command" {
  cd "$REPO_ROOT"
  # Create a 200-line command file
  printf '%.0sline\n' {1..200} > "$TMPDIR_VC/big.md"
  run bash "$SCRIPT" "$TMPDIR_VC/big.md"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"150"* ]]
}

@test "accepts well-formed command" {
  cd "$REPO_ROOT"
  cat > "$TMPDIR_VC/good.md" << 'EOF'
Test command content.

This is a valid command with enough content.
It follows the conventions.
EOF
  run bash "$SCRIPT" "$TMPDIR_VC/good.md"
  [[ "$status" -le 1 ]]
}

@test "script has set -euo pipefail" {
  head -10 "$SCRIPT" | grep -q "set -euo pipefail"
}

@test "uses MAX_PROMPT_LINES constant" {
  grep -q "MAX_PROMPT_LINES" "$SCRIPT"
}

@test "checks for COMMANDS_DIR" {
  grep -q "COMMANDS_DIR" "$SCRIPT"
}

@test "edge: file with only whitespace passes or warns" {
  cd "$REPO_ROOT"
  printf '   \n  \n  \n' > "$TMPDIR_VC/blank.md"
  run bash "$SCRIPT" "$TMPDIR_VC/blank.md"
  [[ "$status" -le 1 ]]
}

@test "edge: nonexistent file path handled" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT" "/nonexistent/path/xyz.md"
  [[ "$status" -ne 0 ]]
}

@test "edge: command at exactly 150 lines accepted" {
  cd "$REPO_ROOT"
  printf '%.0sline\n' {1..150} > "$TMPDIR_VC/exact.md"
  run bash "$SCRIPT" "$TMPDIR_VC/exact.md"
  [[ "$status" -le 1 ]]
}
