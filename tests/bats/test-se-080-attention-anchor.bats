#!/usr/bin/env bats
# tests/bats/test-se-080-attention-anchor.bats
# SE-080 — Attention-anchor vocabulary
# >= 4 tests

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
ANCHOR_DOC="$REPO_ROOT/docs/rules/domain/attention-anchor.md"
CHECK_SCRIPT="$REPO_ROOT/scripts/attention-anchor-check.sh"

# ── Test 1: attention-anchor.md exists and mentions all 4 patterns ────────────
@test "SE-080 AC-01: attention-anchor.md exists and mentions B8, B9, A7, A9" {
  [[ -f "$ANCHOR_DOC" ]]
  grep -q "B8" "$ANCHOR_DOC"
  grep -q "B9" "$ANCHOR_DOC"
  grep -q "A7" "$ANCHOR_DOC"
  grep -q "A9" "$ANCHOR_DOC"
}

# ── Test 2: attention-anchor-check.sh produces valid JSON ────────────────────
@test "SE-080 AC-02: attention-anchor-check.sh produces valid JSON" {
  [[ -f "$CHECK_SCRIPT" ]]
  [[ -x "$CHECK_SCRIPT" ]]
  run bash "$CHECK_SCRIPT"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
  local checked
  checked=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['checked'])")
  [ "$checked" = "4" ]
}

# ── Test 3: B9 referenced in autonomous-safety or radical-honesty (GOAL STEWARD) ─
@test "SE-080 AC-03: B9 GOAL STEWARD referenced in radical-honesty.md or SE-079 spec" {
  local found=0
  grep -q "B9" "$REPO_ROOT/docs/rules/domain/radical-honesty.md" 2>/dev/null && found=1
  grep -q "B9" "$REPO_ROOT/docs/propuestas/SE-079-pr-plan-scope-trace-gate.md" 2>/dev/null && found=1
  [ "$found" -eq 1 ]
}

# ── Test 4: A9 referenced in autonomous-safety.md (SUPERVISED EXECUTION) ─────
@test "SE-080 AC-03: A9 SUPERVISED EXECUTION referenced in autonomous-safety.md" {
  grep -q "A9" "$REPO_ROOT/docs/rules/domain/autonomous-safety.md"
}

# ── Test 5: check script reports found=4, missing=[] in this workspace ────────
@test "SE-080: all 4 patterns found in workspace (found=4, missing empty)" {
  run bash "$CHECK_SCRIPT"
  [ "$status" -eq 0 ]
  local found missing_count
  found=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['found'])")
  missing_count=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['missing']))")
  [ "$found" = "4" ]
  [ "$missing_count" = "0" ]
}

# ── Test 6: attention-anchor.md cites Genesis upstream (SE-080 AC-06) ────────
@test "SE-080 AC-06: attention-anchor.md cites Genesis upstream (danielmeppiel/genesis)" {
  grep -qi "genesis" "$ANCHOR_DOC"
}
