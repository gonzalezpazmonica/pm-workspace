#!/usr/bin/env bats
# BATS tests for SE-021 Code Review Court
# Quality gate: SPEC-055 (audit score ≥80)

SCRIPT="scripts/court-review.sh"
SCHEMA="$BATS_TEST_DIRNAME/../.claude/schemas/review-crc.schema.json"
AGENTS_DIR="$BATS_TEST_DIRNAME/../.claude/agents"
RULES_DIR="$BATS_TEST_DIRNAME/../.claude/rules/domain"
COMMANDS_DIR="$BATS_TEST_DIRNAME/../.claude/commands"

# ── Structural tests ──────────────────────────────────────────────────────

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

# ── Agent tests ──────────────────────────────────────────────────────────

@test "court-orchestrator agent exists with L4 permission" {
  [[ -f "$AGENTS_DIR/court-orchestrator.md" ]]
  grep -q "permission_level: L4" "$AGENTS_DIR/court-orchestrator.md"
}

@test "correctness-judge agent exists with L1 permission" {
  [[ -f "$AGENTS_DIR/correctness-judge.md" ]]
  grep -q "permission_level: L1" "$AGENTS_DIR/correctness-judge.md"
}

@test "architecture-judge agent exists with L1 permission" {
  [[ -f "$AGENTS_DIR/architecture-judge.md" ]]
  grep -q "permission_level: L1" "$AGENTS_DIR/architecture-judge.md"
}

@test "security-judge agent exists with L1 permission" {
  [[ -f "$AGENTS_DIR/security-judge.md" ]]
  grep -q "permission_level: L1" "$AGENTS_DIR/security-judge.md"
}

@test "cognitive-judge agent exists with L1 permission" {
  [[ -f "$AGENTS_DIR/cognitive-judge.md" ]]
  grep -q "permission_level: L1" "$AGENTS_DIR/cognitive-judge.md"
}

@test "spec-judge agent exists with L1 permission" {
  [[ -f "$AGENTS_DIR/spec-judge.md" ]]
  grep -q "permission_level: L1" "$AGENTS_DIR/spec-judge.md"
}

@test "fix-assigner agent exists with L2 permission" {
  [[ -f "$AGENTS_DIR/fix-assigner.md" ]]
  grep -q "permission_level: L2" "$AGENTS_DIR/fix-assigner.md"
}

@test "all 7 Court agents have token_budget in frontmatter" {
  for agent in court-orchestrator correctness-judge architecture-judge security-judge cognitive-judge spec-judge fix-assigner; do
    grep -q "token_budget:" "$AGENTS_DIR/$agent.md"
  done
}

# ── Rule tests ──────────────────────────────────────────────────────────

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

@test "rule documents scoring formula" {
  grep -q "critical.*25" "$RULES_DIR/code-review-court.md"
  grep -q "high.*10" "$RULES_DIR/code-review-court.md"
}

@test "rule documents batch-size gate" {
  grep -q "400" "$RULES_DIR/code-review-court.md"
}

@test "rule documents fix cycle max rounds" {
  grep -q "3 rounds\|max 3" "$RULES_DIR/code-review-court.md"
}

# ── Command tests ──────────────────────────────────────────────────────

@test "court-review command exists" {
  [[ -f "$COMMANDS_DIR/court-review.md" ]]
}

# ── Scoring logic tests ──────────────────────────────────────────────────

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

# ── Hash function tests ──────────────────────────────────────────────────

@test "hash produces 64-char hex for a real file" {
  run bash "$SCRIPT" hash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "${#output}" -eq 64 ]]
  [[ "$output" =~ ^[a-f0-9]{64}$ ]]
}

@test "hash fails gracefully for missing file" {
  run bash "$SCRIPT" hash /nonexistent/file.txt
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"ERROR"* ]]
}

# ── Skeleton tests ──────────────────────────────────────────────────────

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

# ── Integration invariants ──────────────────────────────────────────────

@test "security-judge documents veto power" {
  grep -qi "veto" "$AGENTS_DIR/security-judge.md"
}

@test "cognitive-judge references debuggability at 3AM" {
  grep -qi "3AM\|3am\|debuggab" "$AGENTS_DIR/cognitive-judge.md"
}

@test "spec-judge handles missing spec gracefully" {
  grep -qi "no spec\|no spec_ref\|not provided" "$AGENTS_DIR/spec-judge.md"
}

@test "court-orchestrator references inclusive-review" {
  grep -qi "inclusive.review\|review_sensitivity" "$AGENTS_DIR/court-orchestrator.md"
}

@test "all judge agents produce YAML output format" {
  for agent in correctness-judge architecture-judge security-judge cognitive-judge spec-judge; do
    grep -q "Output format (YAML)\|YAML" "$AGENTS_DIR/$agent.md"
  done
}
