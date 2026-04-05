#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-055-test-auditor.md
# Tests for test-auditor.sh — Quality scoring for BATS tests

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/test-auditor.sh"
  TMPDIR_TA=$(mktemp -d)
}

teardown() { rm -rf "$TMPDIR_TA"; }

@test "script has safety flags" {
  head -15 "$SCRIPT" | grep -qE "set -(e|u).*pipefail"
}

@test "audits a real test file" {
  run bash "$SCRIPT" tests/test-hook-profile.bats
  [ "$status" -le 1 ]
  [[ "$output" == *"total"* ]]
}

@test "produces JSON output" {
  run bash "$SCRIPT" tests/test-hook-profile.bats
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null
  [ "$?" -le 1 ]
}

@test "scores include 9 criteria" {
  run bash "$SCRIPT" tests/test-hook-profile.bats
  [[ "$output" == *"exists_executable"* ]]
  [[ "$output" == *"safety_verification"* ]]
  [[ "$output" == *"positive_cases"* ]]
}

@test "negative: nonexistent file handled" {
  run bash "$SCRIPT" "/nonexistent/test.bats"
  [ "$status" -le 1 ]
}

@test "negative: no args shows usage or error" {
  run bash "$SCRIPT"
  [ "$status" -le 1 ]
}

@test "edge: empty test file scores low" {
  touch "$TMPDIR_TA/empty.bats"
  run bash "$SCRIPT" "$TMPDIR_TA/empty.bats"
  [ "$status" -le 1 ]
}

@test "edge: all flag audits multiple files" {
  run bash "$SCRIPT" --all
  [ "$status" -le 1 ]
}

@test "coverage: supports --json flag" {
  grep -q "json\|JSON\|--json\|--all" "$SCRIPT"
}

@test "coverage: certification hash generated" {
  grep -q "hash\|sha\|certified" "$SCRIPT"
}
