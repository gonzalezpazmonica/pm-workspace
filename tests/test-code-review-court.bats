#!/usr/bin/env bats
# BATS tests for SE-021 Code Review Court
# SPEC: docs/propuestas/savia-enterprise/SPEC-SE-021-code-review-court.md
# SCRIPT: scripts/court-review.sh
# Ref: docs/rules/domain/code-review-court.md
# Quality gate: SPEC-055 (audit score ≥80)
# Safety: tests use BATS run/status guards; target script has set -uo pipefail
# Status: active
# Date: 2026-04-12
# Era: 221
# Problem: AI generates code faster than humans can review (SmartBear: >400 LOC degrades quality)
# Solution: 5 agent-judges + .review.crc verdict + scoring 100-(C*25+H*10+M*3+L*1)
# Acceptance: schema, 7 agents, scoring, batch gate, fix cycle, inclusive review, BATS ≥20
# Dependencies: court-review.sh, review-crc.schema.json, 7 agents, code-review-court.md rule

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/court-review.sh"
  export SCHEMA="$REPO_ROOT/.claude/schemas/review-crc.schema.json"
  export AGENTS_DIR="$REPO_ROOT/.claude/agents"
  export RULES_DIR="$REPO_ROOT/docs/rules/domain"
  export COMMANDS_DIR="$REPO_ROOT/.claude/commands"
}

## Problem: review quality degrades >400 LOC; AI produces code 10x faster than humans review
## Solution: 5 judges + .review.crc + scoring + batch gate + fix cycle
## Acceptance: schema validates, 7 agents exist, scoring correct, batch gate works

## Structural tests

@test "court-review.sh exists and has no syntax errors" {
  [[ -f "$SCRIPT" ]]
  bash -n "$SCRIPT"
}

@test "court-review.sh is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "court-review.sh uses set -uo pipefail" {
  head -3 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "review-crc schema exists and is valid JSON" {
  [[ -f "$SCHEMA" ]]
  python3 -c "import json; json.load(open('$SCHEMA'))"
}

@test "schema defines all 5 judges" {
  for judge in correctness architecture security cognitive spec; do
    grep -q "\"$judge\"" "$SCHEMA"
  done
}

@test "schema defines finding severity enum" {
  grep -q '"critical"' "$SCHEMA"
  grep -q '"high"' "$SCHEMA"
  grep -q '"medium"' "$SCHEMA"
  grep -q '"low"' "$SCHEMA"
  grep -q '"info"' "$SCHEMA"
}

@test "schema requires SHA-256 pattern for file hashes" {
  grep -q 'a-f0-9.*64' "$SCHEMA"
}

## Agent tests

@test "court-orchestrator agent exists with L4 permission" {
  [[ -f "$AGENTS_DIR/court-orchestrator.md" ]]
  grep -q "permission_level: L4" "$AGENTS_DIR/court-orchestrator.md"
}

@test "all 5 judge agents exist with correct permission levels" {
  for judge in correctness-judge architecture-judge security-judge cognitive-judge spec-judge; do
    [[ -f "$AGENTS_DIR/$judge.md" ]]
    grep -q "permission_level: L1" "$AGENTS_DIR/$judge.md"
  done
  [[ -f "$AGENTS_DIR/fix-assigner.md" ]]
  grep -q "permission_level: L2" "$AGENTS_DIR/fix-assigner.md"
}

@test "all 7 Court agents have token_budget in frontmatter" {
  for agent in court-orchestrator correctness-judge architecture-judge security-judge cognitive-judge spec-judge fix-assigner; do
    grep -q "token_budget:" "$AGENTS_DIR/$agent.md"
  done
}

## Rule tests

@test "code-review-court rule exists and is under 150 lines" {
  [[ -f "$RULES_DIR/code-review-court.md" ]]
  local lines
  lines=$(wc -l < "$RULES_DIR/code-review-court.md")
  [[ "$lines" -le 150 ]]
}

@test "rule documents all 5 judges" {
  for judge in correctness architecture security cognitive spec; do
    grep -qi "$judge" "$RULES_DIR/code-review-court.md"
  done
}

@test "rule documents scoring, batch gate 400, and fix cycle max 3" {
  grep -q "critical.*25" "$RULES_DIR/code-review-court.md"
  grep -q "400" "$RULES_DIR/code-review-court.md"
  grep -q "3 rounds\|max 3" "$RULES_DIR/code-review-court.md"
}

## Command tests

@test "court-review command exists" {
  [[ -f "$COMMANDS_DIR/court-review.md" ]]
}

## Scoring logic tests

@test "score 0 criticals = 100 (pass)" {
  run bash "$SCRIPT" score 0 0 0 0
  [[ "$output" == *"score=100"* ]]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "score 1 critical = 75 (conditional)" {
  run bash "$SCRIPT" score 1 0 0 0
  [[ "$output" == *"score=75"* ]]
  [[ "$output" == *"verdict=conditional"* ]]
}

@test "score 4 criticals = 0 (fail, clamped)" {
  run bash "$SCRIPT" score 4 0 0 0
  [[ "$output" == *"score=0"* ]]
  [[ "$output" == *"verdict=fail"* ]]
}

@test "score 2H + 3M + 5L = 66 (fail)" {
  run bash "$SCRIPT" score 0 2 3 5
  [[ "$output" == *"score=66"* ]]
  [[ "$output" == *"verdict=fail"* ]]
}

@test "score 0H + 1M + 2L = 95 (pass)" {
  run bash "$SCRIPT" score 0 0 1 2
  [[ "$output" == *"score=95"* ]]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "score mixed 1C + 1H + 1M + 1L = 61 (fail)" {
  run bash "$SCRIPT" score 1 1 1 1
  [[ "$output" == *"score=61"* ]]
  [[ "$output" == *"verdict=fail"* ]]
}

## Hash function tests

@test "hash produces 64-char hex for a real file" {
  run bash "$SCRIPT" hash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "${#output}" -eq 64 ]]
  [[ "$output" =~ ^[a-f0-9]{64}$ ]]
}

@test "hash fails for nonexistent file" {
  run bash "$SCRIPT" hash /nonexistent/file.txt
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}

@test "score boundary: overflow clamped at zero" {
  run bash "$SCRIPT" score 5 5 5 5
  [[ "$output" == *"score=0"* ]]
}

@test "empty subcommand shows usage" {
  run bash "$SCRIPT"
  [[ "$output" == *"Usage"* ]]
}

## Skeleton tests

@test "skeleton produces valid YAML-like output with review_id" {
  run bash "$SCRIPT" skeleton
  [[ "$output" == *"review_id:"* ]]
  [[ "$output" == *"CRC-"* ]]
}

@test "skeleton includes all 5 judge sections" {
  run bash "$SCRIPT" skeleton
  [[ "$output" == *"correctness:"* ]]
  [[ "$output" == *"architecture:"* ]]
  [[ "$output" == *"security:"* ]]
  [[ "$output" == *"cognitive:"* ]]
  [[ "$output" == *"spec:"* ]]
}

@test "skeleton includes signature section" {
  run bash "$SCRIPT" skeleton
  [[ "$output" == *"signature:"* ]]
  [[ "$output" == *"code-review-court-v1"* ]]
}

## Integration invariants

@test "judges have domain-specific markers (veto, 3AM, missing spec, inclusive)" {
  grep -qi "veto" "$AGENTS_DIR/security-judge.md"
  grep -qi "3AM\|debuggab" "$AGENTS_DIR/cognitive-judge.md"
  grep -qi "no spec\|not provided" "$AGENTS_DIR/spec-judge.md"
  grep -qi "inclusive.review\|review_sensitivity" "$AGENTS_DIR/court-orchestrator.md"
}

@test "all judge agents produce YAML output format" {
  for agent in correctness-judge architecture-judge security-judge cognitive-judge spec-judge; do
    grep -q "YAML" "$AGENTS_DIR/$agent.md"
  done
}
