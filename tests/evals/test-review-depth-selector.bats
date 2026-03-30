#!/usr/bin/env bats
# Tests for SPEC-049 Depth-Adjustable Review — Phase 1
# Validates review-depth-selector.sh score→depth mapping

SCRIPT="scripts/review-depth-selector.sh"

@test "review-depth-selector.sh exists" {
  [ -f "$SCRIPT" ]
}

@test "review-depth-selector.sh is executable" {
  [ -x "$SCRIPT" ]
}

@test "review-depth-selector.sh uses set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "score 0 returns quick depth" {
  run bash "$SCRIPT" 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"depth: quick"* ]]
  [[ "$output" == *"model: haiku"* ]]
}

@test "score 10 returns quick depth" {
  run bash "$SCRIPT" 10
  [ "$status" -eq 0 ]
  [[ "$output" == *"depth: quick"* ]]
  [[ "$output" == *"model: haiku"* ]]
}

@test "score 40 returns standard depth" {
  run bash "$SCRIPT" 40
  [ "$status" -eq 0 ]
  [[ "$output" == *"depth: standard"* ]]
  [[ "$output" == *"model: sonnet"* ]]
  [[ "$output" == *"security"* ]]
}

@test "score 80 returns thorough depth" {
  run bash "$SCRIPT" 80
  [ "$status" -eq 0 ]
  [[ "$output" == *"depth: thorough"* ]]
  [[ "$output" == *"model: opus"* ]]
  [[ "$output" == *"compliance"* ]]
}

@test "SPEC-049 risk-escalation rule exists" {
  [ -f ".claude/rules/domain/risk-escalation.md" ]
}

@test "missing argument shows error" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "non-numeric argument shows error" {
  run bash "$SCRIPT" "abc"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "score over 100 shows error" {
  run bash "$SCRIPT" 101
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "score 25 boundary returns quick" {
  run bash "$SCRIPT" 25
  [ "$status" -eq 0 ]
  [[ "$output" == *"depth: quick"* ]]
}

@test "score 26 boundary returns standard" {
  run bash "$SCRIPT" 26
  [ "$status" -eq 0 ]
  [[ "$output" == *"depth: standard"* ]]
}

@test "score 51 boundary returns thorough" {
  run bash "$SCRIPT" 51
  [ "$status" -eq 0 ]
  [[ "$output" == *"depth: thorough"* ]]
  [[ "$output" == *"model: opus"* ]]
}
