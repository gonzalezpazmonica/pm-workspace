#!/usr/bin/env bats
# Tests for adaptive-strategy-selector.sh — model tier strategy selection
# Ref: .claude/rules/domain/agent-context-budget.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/adaptive-strategy-selector.sh"
  TMPDIR_AS=$(mktemp -d)
  unset SAVIA_MODEL_TIER
}

teardown() {
  rm -rf "$TMPDIR_AS"
  unset SAVIA_MODEL_TIER 2>/dev/null || true
}

@test "target script has safety flags set" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "max tier outputs valid JSON with correct fields" {
  run bash "$SCRIPT" max
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['tier']=='max'"
}

@test "high tier outputs valid JSON strategy" {
  run bash "$SCRIPT" high
  [ "$status" -eq 0 ]
  [[ "$output" == *'"tier":"high"'* ]]
}

@test "fast tier outputs valid JSON strategy" {
  run bash "$SCRIPT" fast
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['tier']=='fast'"
}

@test "reads SAVIA_MODEL_TIER env var when no arg given" {
  export SAVIA_MODEL_TIER=max
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"tier":"max"'* ]]
}

@test "JSON contains lazy_loading field" {
  run bash "$SCRIPT" high
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"lazy_loading"'
}

@test "fails with error for unknown tier" {
  run bash "$SCRIPT" unknown
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "fails with error when no argument and no env var" {
  unset SAVIA_MODEL_TIER
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "fails with error for invalid tier name" {
  run bash "$SCRIPT" premium
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown tier"* ]]
}

@test "handles empty string tier" {
  run bash "$SCRIPT" ""
  # Empty string may be treated as missing arg or default — both acceptable
  [[ "$status" -le 1 ]]
}

@test "edge case: empty SAVIA_MODEL_TIER env var" {
  export SAVIA_MODEL_TIER=""
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}

@test "edge case: boundary tier with null-like value" {
  run bash "$SCRIPT" null
  [ "$status" -eq 1 ]
}

@test "edge case: zero-length argument produces nonexistent tier" {
  export SAVIA_MODEL_TIER="   "
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
}
