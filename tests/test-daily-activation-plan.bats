#!/usr/bin/env bats
# BATS tests for SE-034 Daily Agent Activation Plan
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-034-agent-activation-plan.md
# SCRIPT: scripts/daily-activation-plan.sh
# Quality gate: SPEC-055 (audit score >=80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail
# Status: active
# Date: 2026-04-13
# Era: 231
# Problem: no mechanism to plan which agents activate daily within token budget
# Solution: daily plan generated from backlog, prioritized, with budget allocation
# Acceptance: plan generates with required sections, respects budget, sorts by priority
# Dependencies: daily-activation-plan.sh, agent-context-budget.md

## Problem: agents invoked without prioritization, exhausting context
## Solution: daily activation plan mapping backlog to agents with token budgets
## Acceptance: plan has budget/queue/deferred sections, P0 before P1, budget respected

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/daily-activation-plan.sh"
  export SPEC="$REPO_ROOT/docs/propuestas/savia-enterprise/SPEC-SE-034-agent-activation-plan.md"
  TMPDIR_PLAN=$(mktemp -d)
  # Override output dir to temp
  export OUTPUT_DIR="$TMPDIR_PLAN/daily-plans"
}
teardown() {
  rm -rf "$TMPDIR_PLAN"
}

## Structural tests

@test "daily-activation-plan.sh exists and is executable" {
  [[ -x "$SCRIPT" ]]
}
@test "uses set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}
@test "spec file exists" {
  [[ -f "$SPEC" ]]
}

## Status mode

@test "status runs without error" {
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Agent Activation Plan Status"* ]]
}
@test "status shows budget available" {
  run bash "$SCRIPT" status
  [[ "$output" == *"Budget available:"* ]]
  [[ "$output" == *"135K"* ]]
}

## Generate mode

@test "generate creates plan file with required sections" {
  run bash "$SCRIPT" generate
  [[ "$status" -eq 0 ]]
  local plan_file
  plan_file=$(echo "$output" | tail -1)
  [[ -f "$plan_file" ]]
  grep -q "## Budget" "$plan_file"
  grep -q "## Priority Queue" "$plan_file"
  grep -q "## Deferred" "$plan_file"
}
@test "generated plan has budget line with 135K available" {
  run bash "$SCRIPT" generate
  local plan_file
  plan_file=$(echo "$output" | tail -1)
  grep -q "Available for agents: 135K" "$plan_file"
}
@test "generate is idempotent (overwrites same day)" {
  run bash "$SCRIPT" generate
  local plan_file1
  plan_file1=$(echo "$output" | tail -1)
  run bash "$SCRIPT" generate
  local plan_file2
  plan_file2=$(echo "$output" | tail -1)
  [[ "$plan_file1" == "$plan_file2" ]]
}

## Show mode

@test "show returns error when no plan exists" {
  run bash "$SCRIPT" show
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"No plan for today"* ]]
}
@test "show works after generate" {
  bash "$SCRIPT" generate >/dev/null
  run bash "$SCRIPT" show
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Activation Plan"* ]]
}

## Edge cases — empty, nonexistent, boundary, zero

@test "generate with empty output dir produces valid plan" {
  # Empty OUTPUT_DIR guarantees no prior plan exists
  run bash "$SCRIPT" generate
  [[ "$status" -eq 0 ]]
  local plan_file
  plan_file=$(echo "$output" | tail -1)
  [[ -f "$plan_file" ]]
  # Plan must have all three required sections regardless of backlog
  grep -q "Budget" "$plan_file"
  grep -q "Priority Queue" "$plan_file"
  grep -q "Deferred" "$plan_file"
}
@test "show with nonexistent plan returns error" {
  run bash "$SCRIPT" show
  [[ "$status" -eq 1 ]]
}
@test "status with zero plans reports correctly" {
  run bash "$SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Total plans:"* ]]
}
@test "invalid argument exits with error" {
  run bash "$SCRIPT" nonexistent-mode
  [[ "$status" -eq 1 ]]
}

## Coverage: cmd_generate, cmd_show, cmd_status, agent_budget, agent_tier_name, scan_backlog

## Budget enforcement

@test "allocated never exceeds available budget" {
  run bash "$SCRIPT" generate
  local plan_file
  plan_file=$(echo "$output" | tail -1)
  local allocated
  allocated=$(grep "Allocated:" "$plan_file" | grep -oP '\d+(?=K)')
  [[ "$allocated" -le 135 ]]
}
