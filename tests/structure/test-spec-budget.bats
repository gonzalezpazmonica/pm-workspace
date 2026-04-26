#!/usr/bin/env bats
# Ref: SE-074 Slice 1.5 — spec-budget.sh (Poisson-clipped retry budget)

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/spec-budget.sh"
  export SPEC_BUDGET_DETERMINISTIC=1
}

@test "budget: S effort returns 2 (lambda_S clipped)" {
  run bash "$SCRIPT" S
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "budget: M effort returns 3 (lambda_M clipped)" {
  run bash "$SCRIPT" M
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "budget: L effort returns 5 (lambda_L clipped)" {
  run bash "$SCRIPT" L
  [ "$status" -eq 0 ]
  [ "$output" = "5" ]
}

@test "budget: lowercase effort accepted (case insensitive)" {
  run bash "$SCRIPT" m
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "budget: invalid effort exits 2 with usage error" {
  run bash "$SCRIPT" XL
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be one of"* ]]
}

@test "budget: missing effort exits 2 with usage" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage"* ]]
}

@test "budget: respects R_MIN floor" {
  SPEC_BUDGET_R_MIN=4 run bash "$SCRIPT" S
  [ "$status" -eq 0 ]
  [ "$output" = "4" ]
}

@test "budget: respects R_MAX ceiling" {
  SPEC_BUDGET_R_MAX=4 run bash "$SCRIPT" L
  [ "$status" -eq 0 ]
  [ "$output" = "4" ]
}

@test "budget: deterministic mode same input → same output" {
  local r1 r2
  r1=$(bash "$SCRIPT" M spec_x)
  r2=$(bash "$SCRIPT" M spec_x)
  [ "$r1" = "$r2" ]
}

@test "budget: stochastic mode produces values in [R_MIN, R_MAX]" {
  for spec in spec_a spec_b spec_c spec_d spec_e; do
    SPEC_BUDGET_DETERMINISTIC=0 run bash "$SCRIPT" M "$spec"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
    [ "$output" -ge 2 ]
    [ "$output" -le 8 ]
  done
}

@test "budget: stochastic mode same spec_id produces same value (reproducible)" {
  local r1 r2
  r1=$(SPEC_BUDGET_DETERMINISTIC=0 bash "$SCRIPT" M consistent_id)
  r2=$(SPEC_BUDGET_DETERMINISTIC=0 bash "$SCRIPT" M consistent_id)
  [ "$r1" = "$r2" ]
}

@test "edge: budget with very low custom range" {
  SPEC_BUDGET_R_MIN=1 SPEC_BUDGET_R_MAX=1 run bash "$SCRIPT" L
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "edge: empty effort string treated as missing" {
  run bash "$SCRIPT" ""
  [ "$status" -eq 2 ]
}

@test "spec ref: SE-074 Slice 1.5 + Kohli 2026 cited in script header" {
  grep -q "SE-074" "$SCRIPT"
  grep -q "Kohli" "$SCRIPT"
  grep -q "arXiv:2604.07822" "$SCRIPT"
}

@test "safety: spec-budget.sh has set -uo pipefail" {
  grep -q 'set -[uo]*o pipefail' "$SCRIPT"
}
