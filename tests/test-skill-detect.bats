#!/usr/bin/env bats
# BATS tests for SE-030 Skill Self-Improvement Pipeline
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-030-skill-self-improvement.md
# SCRIPT: scripts/skill-detect.sh
# Quality gate: SPEC-055 (audit score >=80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail
# Status: active
# Date: 2026-04-13
# Era: 231
# Problem: skills improve only via manual intervention, no learning loop
# Solution: detect patterns from invocation logs, propose skills, suggest refinements
# Acceptance: scan detects patterns, propose creates valid scaffold, refine suggests improvements
# Dependencies: skill-detect.sh, skill-feedback-log.sh

## Problem: no automatic learning from repeated task patterns
## Solution: 3-phase pipeline — scan logs → propose skills → refine existing
## Acceptance: scan works on empty/real data, propose creates SKILL.md+DOMAIN.md, refine finds failures

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/skill-detect.sh"
  export SPEC="$REPO_ROOT/docs/propuestas/savia-enterprise/SPEC-SE-030-skill-self-improvement.md"
  TMPDIR_SD=$(mktemp -d)
  export PROPOSALS_DIR="$TMPDIR_SD/proposals"
  export INVOCATIONS_LOG="$TMPDIR_SD/invocations.jsonl"
}
teardown() {
  rm -rf "$TMPDIR_SD"
}

## Structural tests

@test "skill-detect.sh exists and is executable" {
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
  [[ "$output" == *"Skill Self-Improvement Status"* ]]
}
@test "status shows active skills count" {
  run bash "$SCRIPT" status
  [[ "$output" == *"Active skills:"* ]]
}

## Scan mode

@test "scan handles empty invocations log gracefully" {
  run bash "$SCRIPT" scan
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No invocation data"* ]]
}
@test "scan with data produces report" {
  # Create synthetic invocation data
  for i in $(seq 1 5); do
    echo "{\"skill\":\"sprint-status\",\"command\":\"sprint-status\",\"outcome\":\"success\",\"timestamp\":\"2026-04-1${i}T10:00:00Z\"}" >> "$INVOCATIONS_LOG"
  done
  run bash "$SCRIPT" scan
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Invocations analyzed: 5"* ]]
}

## Propose mode

@test "propose creates valid SKILL.md scaffold" {
  run bash "$SCRIPT" propose "test-auto-skill" "Test skill description" "quality"
  [[ "$status" -eq 0 ]]
  [[ -f "$PROPOSALS_DIR/test-auto-skill/SKILL.md" ]]
  grep -q "^name: test-auto-skill" "$PROPOSALS_DIR/test-auto-skill/SKILL.md"
  grep -q "confidence: 50" "$PROPOSALS_DIR/test-auto-skill/SKILL.md"
  grep -q "maturity: experimental" "$PROPOSALS_DIR/test-auto-skill/SKILL.md"
}
@test "propose creates DOMAIN.md alongside SKILL.md" {
  run bash "$SCRIPT" propose "test-domain-skill" "Domain test"
  [[ "$status" -eq 0 ]]
  [[ -f "$PROPOSALS_DIR/test-domain-skill/DOMAIN.md" ]]
  grep -q "Conceptos de dominio" "$PROPOSALS_DIR/test-domain-skill/DOMAIN.md"
}
@test "propose SKILL.md respects 150-line limit" {
  bash "$SCRIPT" propose "line-check" "Check lines" >/dev/null
  local lines
  lines=$(wc -l < "$PROPOSALS_DIR/line-check/SKILL.md")
  [[ "$lines" -le 150 ]]
}
@test "propose includes confidence of 50 percent" {
  bash "$SCRIPT" propose "conf-check" "Confidence check" >/dev/null
  grep -q "confidence: 50" "$PROPOSALS_DIR/conf-check/SKILL.md"
}

## Propose — negative cases

@test "propose fails without name argument" {
  run bash "$SCRIPT" propose
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Usage"* ]]
}
@test "propose rejects invalid name (not kebab-case)" {
  run bash "$SCRIPT" propose "NotKebab"
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"kebab-case"* ]]
}

## Refine mode

@test "refine handles empty data gracefully" {
  run bash "$SCRIPT" refine
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No invocation data"* ]]
}

## Edge cases — empty, nonexistent, boundary, zero

@test "scan on nonexistent log path returns gracefully" {
  export INVOCATIONS_LOG="/tmp/nonexistent-file-xyz.jsonl"
  run bash "$SCRIPT" scan
  [[ "$status" -eq 0 ]]
}
@test "status with zero proposals shows 0" {
  run bash "$SCRIPT" status
  [[ "$output" == *"Pending proposals:   0"* ]]
}
@test "invalid subcommand exits with error" {
  run bash "$SCRIPT" nonexistent-mode
  [[ "$status" -eq 1 ]]
}

## Coverage: cmd_scan, cmd_propose, cmd_refine, cmd_status
