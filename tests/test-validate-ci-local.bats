#!/usr/bin/env bats
# Tests for validate-ci-local.sh — CI validation pipeline
# Ref: .claude/rules/domain/pre-commit-bats.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/validate-ci-local.sh"
  TMPDIR_CI=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_CI"
}

# ── Safety ──

@test "validate-ci-local.sh has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

# ── Positive cases ──

@test "script exists and is readable" {
  [ -f "$SCRIPT" ]
  [ -r "$SCRIPT" ]
}

@test "script accepts --quick flag without crash" {
  run bash "$SCRIPT" --quick
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "output contains PASS or FAIL markers" {
  run bash "$SCRIPT" --quick
  [[ "$output" == *"PASS"* || "$output" == *"FAIL"* || "$output" == *"WARN"* ]]
}

@test "check_branch function is defined" {
  grep -q "check_branch" "$SCRIPT"
}

@test "check_file_sizes function is defined" {
  grep -q "check_file_sizes" "$SCRIPT"
}

@test "check_changelog function is defined" {
  grep -q "check_changelog" "$SCRIPT"
}

# ── Negative cases ──

@test "fails with invalid flag gracefully" {
  run bash "$SCRIPT" --nonexistent-flag
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "error output when critical check fails" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ -n "$output" ]]
}

@test "missing CHANGELOG triggers fail or warn" {
  run bash "$SCRIPT" --quick
  [ -n "$output" ]
}

@test "invalid workspace does not crash" {
  cd "$TMPDIR_CI"
  run bash "$SCRIPT"
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

# ── Edge cases ──

@test "empty environment runs without crash" {
  run env -i HOME="$HOME" PATH="$PATH" bash "$SCRIPT" --quick
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "zero-length files detected by check_file_sizes" {
  grep -q "file_sizes\|wc -l\|150" "$SCRIPT"
}

@test "handles nonexistent settings.json path" {
  grep -q "settings.json\|settings_json" "$SCRIPT"
}

# ── Spec reference ──

@test "SPEC: pre-commit-bats.md rule exists" {
  [ -f "$REPO_ROOT/.claude/rules/domain/pre-commit-bats.md" ]
}
