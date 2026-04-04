#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-078-dual-estimation-agent-human.md
# Tests for dual-estimate.sh — Dual estimation engine

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/dual-estimate.sh"
  TMPDIR_DE=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_DE"
}

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "help shows usage" {
  run bash "$SCRIPT" help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"classify"* ]]
  [[ "$output" == *"capacity"* ]]
  [[ "$output" == *"bottleneck"* ]]
}

@test "classify crud recommends agent" {
  run bash "$SCRIPT" classify crud
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"recommend=AGENT"* ]]
}

@test "classify architecture recommends human" {
  run bash "$SCRIPT" classify architecture
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"HUMAN_ALWAYS"* ]]
}

@test "classify code-review is always human" {
  run bash "$SCRIPT" classify code-review
  [[ "$output" == *"HUMAN_ALWAYS"* ]]
}

@test "classify all 10 types succeed" {
  for t in crud tests translation bugfix refactor architecture code-review security-audit counter-fix business-decision; do
    run bash "$SCRIPT" classify "$t"
    [[ "$status" -eq 0 ]]
  done
}

@test "negative: classify unknown type fails" {
  run bash "$SCRIPT" classify unknown-xyz
  [[ "$status" -ne 0 ]]
}

@test "negative: classify without arg fails" {
  run bash "$SCRIPT" classify
  [[ "$status" -ne 0 ]]
}

@test "capacity calculates correctly" {
  run bash "$SCRIPT" capacity 40 10 15
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Team capacity"* ]]
  [[ "$output" == *"150min"* ]]
}

@test "bottleneck detects overload" {
  run bash "$SCRIPT" bottleneck 10 400
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"BOTTLENECK"* ]]
}

@test "bottleneck passes under threshold" {
  run bash "$SCRIPT" bottleneck 40 100
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OK"* ]]
}

@test "matrix shows decision table" {
  run bash "$SCRIPT" matrix
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"CRUD"* ]]
  [[ "$output" == *"Golden rule"* ]]
}

@test "negative: unknown command fails" {
  run bash "$SCRIPT" bogus
  [[ "$status" -eq 1 ]]
}

@test "edge: capacity with zero tasks" {
  run bash "$SCRIPT" capacity 40 0 15
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"0min"* ]]
}

@test "edge: bottleneck at exactly 30%" {
  run bash "$SCRIPT" bottleneck 100 1800
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"30%"* ]]
}

@test "coverage: classify_task function exists" {
  grep -q "classify_task()" "$SCRIPT"
}

@test "coverage: check_bottleneck function exists" {
  grep -q "check_bottleneck()" "$SCRIPT"
}
