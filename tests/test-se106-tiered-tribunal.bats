#!/usr/bin/env bats
# Tests for SE-106: Tiered tribunal execution
# Ref: docs/propuestas/SE-106-tiered-tribunal-execution.md
# Ref: docs/rules/domain/tribunal-execution.md

HELPER="${BATS_TEST_DIRNAME}/../scripts/savia-orchestrator-helper.sh"
AGENTS_DIR="${BATS_TEST_DIRNAME}/../.opencode/agents"

setup() {
  [[ -f "$HELPER" ]] || skip "savia-orchestrator-helper.sh missing"
}

# ── AC-1: tier subcommand returns valid JSON ──────────────────────────────

@test "tier truth_tribunal returns JSON with tier0 and tier1 keys" {
  run bash "$HELPER" tier truth_tribunal
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'tier0' in d and 'tier1' in d"
}

@test "tier court returns JSON with tier0 and tier1 keys" {
  run bash "$HELPER" tier court
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'tier0' in d and 'tier1' in d"
}

@test "tier recommendation_tribunal returns empty tier0 (parallel-only)" {
  run bash "$HELPER" tier recommendation_tribunal
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['tier0'] == [], f'tier0={d[\"tier0\"]}'"
}

# ── AC-2: Truth Tribunal tier0 contains required judges ──────────────────

@test "tier0 of truth_tribunal contains hallucination-judge" {
  run bash "$HELPER" tier truth_tribunal
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'hallucination-judge' in d['tier0'], f'tier0={d[\"tier0\"]}'"
}

@test "tier0 of truth_tribunal contains compliance-judge" {
  run bash "$HELPER" tier truth_tribunal
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'compliance-judge' in d['tier0'], f'tier0={d[\"tier0\"]}'"
}

@test "tier0 of truth_tribunal contains factuality-judge" {
  run bash "$HELPER" tier truth_tribunal
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'factuality-judge' in d['tier0'], f'tier0={d[\"tier0\"]}'"
}

# ── AC-3: Court tier0 contains required judges ────────────────────────────

@test "tier0 of court contains correctness-judge and security-judge" {
  run bash "$HELPER" tier court
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert 'correctness-judge' in d['tier0'], f'correctness-judge missing: {d[\"tier0\"]}'
assert 'security-judge' in d['tier0'], f'security-judge missing: {d[\"tier0\"]}'
"
}

@test "tier1 of court contains architecture-judge and cognitive-judge" {
  run bash "$HELPER" tier court
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert 'architecture-judge' in d['tier1'], f'architecture-judge missing: {d[\"tier1\"]}'
assert 'cognitive-judge' in d['tier1'], f'cognitive-judge missing: {d[\"tier1\"]}'
"
}

# ── AC-4: Recommendation Tribunal note present ────────────────────────────

@test "recommendation-tribunal-orchestrator.md contains SE-106 no-tiered note" {
  local rec_file="${AGENTS_DIR}/recommendation-tribunal-orchestrator.md"
  [ -f "$rec_file" ]
  grep -q "tiered execution no aplica" "$rec_file"
}

# ── AC-5: TRIBUNAL_FORCE_FULL_PANEL override ─────────────────────────────

@test "TRIBUNAL_FORCE_FULL_PANEL=1 moves tier0 judges to tier1 for truth_tribunal" {
  run env TRIBUNAL_FORCE_FULL_PANEL=1 bash "$HELPER" tier truth_tribunal
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['tier0'] == [], f'tier0 should be empty: {d[\"tier0\"]}'
assert 'hallucination-judge' in d['tier1'], f'hallucination-judge missing from tier1: {d[\"tier1\"]}'
assert 'compliance-judge' in d['tier1'], f'compliance-judge missing from tier1: {d[\"tier1\"]}'
"
}

@test "TRIBUNAL_FORCE_FULL_PANEL=1 moves tier0 judges to tier1 for court" {
  run env TRIBUNAL_FORCE_FULL_PANEL=1 bash "$HELPER" tier court
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['tier0'] == [], f'tier0 should be empty: {d[\"tier0\"]}'
assert 'security-judge' in d['tier1'], f'security-judge missing from tier1: {d[\"tier1\"]}'
assert 'correctness-judge' in d['tier1'], f'correctness-judge missing from tier1: {d[\"tier1\"]}'
"
}

# ── AC-1 / judges subcommand ──────────────────────────────────────────────

@test "judges subcommand for court outputs tab-separated tier and judge names" {
  run bash "$HELPER" judges court
  [ "$status" -eq 0 ]
  # At least one line should have "tier0\t..." format
  echo "$output" | grep -q "^tier0"
  echo "$output" | grep -q "^tier1"
}

# ── Size constraint: agents <= 4096 bytes ─────────────────────────────────

@test "truth-tribunal-orchestrator.md is <= 4096 bytes" {
  local f="${AGENTS_DIR}/truth-tribunal-orchestrator.md"
  [ -f "$f" ]
  local size
  size=$(wc -c < "$f")
  [ "$size" -le 4096 ]
}

@test "court-orchestrator.md is <= 4096 bytes" {
  local f="${AGENTS_DIR}/court-orchestrator.md"
  [ -f "$f" ]
  local size
  size=$(wc -c < "$f")
  [ "$size" -le 4096 ]
}

@test "recommendation-tribunal-orchestrator.md is <= 4096 bytes" {
  local f="${AGENTS_DIR}/recommendation-tribunal-orchestrator.md"
  [ -f "$f" ]
  local size
  size=$(wc -c < "$f")
  [ "$size" -le 4096 ]
}

# ── Schema fields present in agent files ──────────────────────────────────

@test "truth-tribunal-orchestrator.md contains tier0_verdict field in schema" {
  grep -q "tier0_verdict" "${AGENTS_DIR}/truth-tribunal-orchestrator.md"
}

@test "court-orchestrator.md contains tier0_verdict field in schema" {
  grep -q "tier0_verdict" "${AGENTS_DIR}/court-orchestrator.md"
}

@test "truth-tribunal-orchestrator.md contains tokens_saved_vs_parallel field" {
  grep -q "tokens_saved_vs_parallel" "${AGENTS_DIR}/truth-tribunal-orchestrator.md"
}

@test "court-orchestrator.md contains tokens_saved_vs_parallel field" {
  grep -q "tokens_saved_vs_parallel" "${AGENTS_DIR}/court-orchestrator.md"
}

# ── SE-106: tribunal-execution rule exists ────────────────────────────────

@test "tribunal-execution.md rule file exists and is non-empty" {
  local rule="${BATS_TEST_DIRNAME}/../docs/rules/domain/tribunal-execution.md"
  [ -f "$rule" ]
  [ -s "$rule" ]
}

@test "tribunal-execution.md contains tiered and parallel-only policy entries" {
  local rule="${BATS_TEST_DIRNAME}/../docs/rules/domain/tribunal-execution.md"
  grep -q "Tiered hybrid" "$rule"
  grep -q "Parallel only" "$rule"
}

# ── tier subcommand rejects unknown tribunal type ─────────────────────────

@test "tier subcommand exits non-zero for unknown tribunal type" {
  run bash "$HELPER" tier unknown_tribunal
  [ "$status" -ne 0 ]
}

@test "judges subcommand exits non-zero for unknown tribunal type" {
  run bash "$HELPER" judges unknown_tribunal
  [ "$status" -ne 0 ]
}
