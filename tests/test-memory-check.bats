#!/usr/bin/env bats
# Ref: .claude/commands/memory-check.md
# Tests for scripts/memory-check.sh — 10-layer memory health check

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/memory-check.sh"
}

@test "memory-check script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "memory-check runs without crashing" {
  run bash "$SCRIPT"
  # 0 = all ok, 0 = warnings, 1 = fails — all non-crashing
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "memory-check output has the expected header" {
  run bash "$SCRIPT"
  [[ "$output" == *"Savia Memory Health Check"* ]]
}

@test "memory-check exercises all 10 layers" {
  run bash "$SCRIPT"
  [[ "$output" == *"[1/10]"* ]]
  [[ "$output" == *"[2/10]"* ]]
  [[ "$output" == *"[3/10]"* ]]
  [[ "$output" == *"[4/10]"* ]]
  [[ "$output" == *"[5/10]"* ]]
  [[ "$output" == *"[6/10]"* ]]
  [[ "$output" == *"[7/10]"* ]]
  [[ "$output" == *"[8/10]"* ]]
  [[ "$output" == *"[9/10]"* ]]
  [[ "$output" == *"[10/10]"* ]]
}

@test "memory-check reports PASS/WARN/FAIL summary" {
  run bash "$SCRIPT"
  [[ "$output" == *"PASS:"* ]]
  [[ "$output" == *"WARN:"* ]]
  [[ "$output" == *"FAIL:"* ]]
}

@test "memory-check command file has required frontmatter" {
  cmd="$REPO_ROOT/.claude/commands/memory-check.md"
  [[ -f "$cmd" ]]
  grep -q '^name: memory-check' "$cmd"
  grep -q '^description:' "$cmd"
}

@test "memory-check script has set -uo pipefail" {
  head -5 "$SCRIPT" | grep -q 'set -uo pipefail'
}
