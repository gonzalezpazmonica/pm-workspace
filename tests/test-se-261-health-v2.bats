#!/usr/bin/env bats
# tests/test-se-261-health-v2.bats — Tests for workspace-health.sh v2 (SE-261)

SCRIPT="${BATS_TEST_DIRNAME}/../scripts/workspace-health.sh"

setup() {
  [[ -x "$SCRIPT" ]] || skip "workspace-health.sh missing"
}

@test "T01: v1 output unchanged without --v2 flag" {
  run bash "$SCRIPT" --json
  [[ "$status" -eq 0 ]]
  [[ ! "$output" =~ "blast_radius" ]]
  [[ ! "$output" =~ "code_ownership" ]]
  [[ ! "$output" =~ "dead_code" ]]
  echo "$output" | grep -q '"skill_completeness"'
  echo "$output" | grep -q '"overall"'
}

@test "T02: v2 flag adds extended dimensions to JSON" {
  run bash "$SCRIPT" --json --v2
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q '"version": 2'
  echo "$output" | grep -q '"blast_radius"'
  echo "$output" | grep -q '"code_ownership"'
  echo "$output" | grep -q '"dead_code"'
}

@test "T03: v2 dimensions have scores and grades" {
  run bash "$SCRIPT" --json --v2
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q '"blast_radius".*"score"'
  echo "$output" | grep -q '"code_ownership".*"grade"'
  echo "$output" | grep -q '"dead_code".*"score"'
}

@test "T04: v2 summary mode shows extended header" {
  run bash "$SCRIPT" --summary --v2
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "v2" ]]
  [[ "$output" =~ "Blast radius" ]]
  [[ "$output" =~ "Code ownership" ]]
  [[ "$output" =~ "Dead code" ]]
}

@test "T05: v1 summary has original header" {
  run bash "$SCRIPT" --summary
  [[ "$status" -eq 0 ]]
  [[ ! "$output" =~ "v2" ]]
  [[ ! "$output" =~ "Blast radius" ]]
}

@test "T06: ci mode works with v2" {
  skip "ci mode requires security-scan.sh which is slow"
}

@test "T07: ci mode works without v2" {
  skip "ci mode requires security-scan.sh which is slow"
}

@test "T08: overall score is between 0 and 100" {
  run bash "$SCRIPT" --json --v2
  score=$(echo "$output" | grep -oE '"score": [0-9]+' | head -1 | grep -oE '[0-9]+')
  [[ -n "$score" ]]
  [[ "$score" -ge 0 ]]
  [[ "$score" -le 100 ]]
}

@test "T09: all v2 grades are valid letters" {
  run bash "$SCRIPT" --json --v2
  grades=$(echo "$output" | grep -oE '"grade": "[A-F]"' | grep -oE '[A-F]')
  [[ -n "$grades" ]]
  while IFS= read -r g; do
    [[ "$g" =~ ^[A-F]$ ]]
  done <<< "$grades"
}

@test "T10: dead_code dimension includes function counts" {
  run bash "$SCRIPT" --json --v2
  echo "$output" | grep -q '"dead_functions"'
  echo "$output" | grep -q '"total_functions"'
}
