#!/usr/bin/env bats
# tests/test-se-260-blast-radius.bats — Tests for blast-radius.sh (SE-260)

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/blast-radius.sh"

setup() {
  [[ -x "$SCRIPT" ]] || skip "blast-radius.sh missing"
}

@test "T01: rejects missing file" {
  run bash "$SCRIPT" no-existe.ts
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "not found" ]]
}

@test "T02: rejects depth out of range" {
  run bash "$SCRIPT" --depth 10 scripts/workspace-health.sh
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "depth must be 1-5" ]]
}

@test "T03: accepts depth 1" {
  run bash "$SCRIPT" --depth 1 scripts/workspace-health.sh
  [[ "$status" -eq 0 ]]
}

@test "T04: accepts depth 5" {
  run bash "$SCRIPT" --depth 5 scripts/workspace-health.sh
  [[ "$status" -eq 0 ]]
}

@test "T05: table mode produces output with Blast Radius header" {
  run bash "$SCRIPT" --depth 1 --format table scripts/workspace-health.sh
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Blast Radius" ]]
  [[ "$output" =~ "Summary" ]]
}

@test "T06: json mode produces valid JSON" {
  run bash "$SCRIPT" --depth 1 --format json scripts/workspace-health.sh
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q '"file"'
  echo "$output" | grep -q '"risk_score"'
}

@test "T07: json mode has required fields" {
  run bash "$SCRIPT" --depth 1 --format json scripts/workspace-health.sh
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q '"total_impacted"'
  echo "$output" | grep -q '"risk_level"'
  echo "$output" | grep -q '"impacted"'
}

@test "T08: no args shows error" {
  run bash "$SCRIPT"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "at least one file required" ]]
}

@test "T09: help flag works" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Usage" ]]
}

@test "T10: returns success for existing file" {
  run bash "$SCRIPT" --depth 1 scripts/pr-thermal-receipt.sh
  [[ "$status" -eq 0 ]]
}
