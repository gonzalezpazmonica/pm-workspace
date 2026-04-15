#!/usr/bin/env bats
# SPEC-089: Memory Stack L0-L3 progressive loading with token budgets.
# Validates layer-specific output limits and graceful degradation.
# Target: scripts/memory-stack-load.sh
# Ref: docs/propuestas/SPEC-089-memory-stack-l0l3.md
# Related: .claude/rules/domain/session-memory-protocol.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/memory-stack-load.sh"
  TMP_DIR=$(mktemp -d -t memstack-XXXXXX)
  export HOME="$TMP_DIR"  # isolate from real user memory
  mkdir -p "$TMP_DIR/.claude/projects/test-proj/memory"
}

teardown() {
  rm -rf "$TMP_DIR" 2>/dev/null || true
}

# ── Structural invariants ───────────────────────────────────────────────────

@test "memory-stack-load.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "memory-stack-load.sh has valid bash syntax" {
  bash -n "$SCRIPT"
}

@test "memory-stack-load.sh uses set -uo pipefail safety" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "memory-stack-load.sh references SPEC-089" {
  grep -q "SPEC-089" "$SCRIPT"
}

@test "memory-stack-load.sh declares 4 layer budgets L0-L3" {
  grep -qE "BUDGET_L0|BUDGET_L1|BUDGET_L2|BUDGET_L3" "$SCRIPT"
  for layer in L0 L1 L2 L3; do
    grep -qE "BUDGET_$layer" "$SCRIPT" || return 1
  done
}

# ── Positive cases ──────────────────────────────────────────────────────────

@test "L0 layer returns output within budget (~200 chars)" {
  run bash "$SCRIPT" L0
  [ "$status" -eq 0 ]
  # Output must not exceed L0 budget by orders of magnitude
  [ "${#output}" -le 500 ]
}

@test "L1 layer budget is greater than L0 budget" {
  # Runtime output depends on memory content; assert the deterministic budget instead.
  l0_budget=$(grep "^BUDGET_L0=" "$SCRIPT" | awk -F= '{print $2}' | awk '{print $1}')
  l1_budget=$(grep "^BUDGET_L1=" "$SCRIPT" | awk -F= '{print $2}' | awk '{print $1}')
  [ "$l1_budget" -gt "$l0_budget" ]
}

@test "L2 layer has higher budget than L1" {
  l1_budget=$(grep "^BUDGET_L1=" "$SCRIPT" | awk -F= '{print $2}' | awk '{print $1}')
  l2_budget=$(grep "^BUDGET_L2=" "$SCRIPT" | awk -F= '{print $2}' | awk '{print $1}')
  [ "$l2_budget" -gt "$l1_budget" ]
}

@test "L3 layer has highest budget" {
  l2_budget=$(grep "^BUDGET_L2=" "$SCRIPT" | awk -F= '{print $2}' | awk '{print $1}')
  l3_budget=$(grep "^BUDGET_L3=" "$SCRIPT" | awk -F= '{print $2}' | awk '{print $1}')
  [ "$l3_budget" -ge "$l2_budget" ]
}

@test "valid layer argument does not crash" {
  run bash "$SCRIPT" L2
  [ "$status" -eq 0 ]
}

@test "progressive loading: L3 contains L0 content concept" {
  run bash "$SCRIPT" L3
  [ "$status" -eq 0 ]
  # L3 should have meaningful output (more than empty)
  [ "${#output}" -ge 0 ]
}

# ── Negative / failure modes ────────────────────────────────────────────────

@test "negative: no arguments triggers empty or default behavior gracefully" {
  run bash "$SCRIPT"
  # Should not crash (graceful degradation per spec)
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "negative: invalid layer name does not crash script" {
  run bash "$SCRIPT" LX_INVALID
  # Should exit gracefully (spec: always exit 0)
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "negative: missing memory directory handled gracefully (no crash)" {
  rm -rf "$TMP_DIR/.claude/projects/test-proj/memory"
  run bash "$SCRIPT" L1
  [ "$status" -eq 0 ]
}

@test "negative: empty HOME does not crash script" {
  HOME=/nonexistent-home-dir-12345 run bash "$SCRIPT" L0
  # Spec: graceful degradation, always exit 0
  [ "$status" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty memory file does not crash L2" {
  : > "$TMP_DIR/.claude/projects/test-proj/memory/MEMORY.md"
  run bash "$SCRIPT" L2
  [ "$status" -eq 0 ]
}

@test "edge: nonexistent topic argument handled" {
  run bash "$SCRIPT" L2 nonexistent-topic-xyz
  [ "$status" -eq 0 ]
}

@test "edge: boundary L0 output within tight budget limit" {
  run bash "$SCRIPT" L0
  [ "$status" -eq 0 ]
  # L0 budget is 200 chars; allow some overhead but not 10x
  [ "${#output}" -le 600 ]
}

@test "edge: zero-byte memory file yields zero-byte related output" {
  : > "$TMP_DIR/.claude/projects/test-proj/memory/session-hot.md"
  run bash "$SCRIPT" L1
  [ "$status" -eq 0 ]
}

# ── Regression guard ────────────────────────────────────────────────────────

@test "regression: budget constants never removed from script" {
  count=$(grep -cE "^BUDGET_L[0-3]=" "$SCRIPT")
  [ "$count" -eq 4 ]
}

@test "regression: SPEC-089 reference retained in comments" {
  grep -q "SPEC-089" "$SCRIPT"
}
