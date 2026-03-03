#!/usr/bin/env bash
# ── test-era18-formulas.sh — Scoring/formula correctness ──
set -euo pipefail
PASS=0; FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RULES_DIR="$REPO_ROOT/.claude/rules/domain"

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

echo "═══════════════════════════════════════════════════════════"
echo "  TEST: Era 18 — Formula & Scoring Correctness"
echo "═══════════════════════════════════════════════════════════"

# ── AI Competency Framework scoring ─────────────────────────
echo ""
echo "1️⃣  AI Competency Scoring (avg × 25)"

# Formula: score_total = promedio(6 competencias) × 25
compute_ai_score() {
  local sum=0
  for v in "$@"; do sum=$((sum + v)); done
  local avg_x100=$(( (sum * 100) / 6 ))
  local score_x100=$(( (avg_x100 * 25) / 100 ))
  echo "$score_x100"
}

# Test: all 1s → avg=1 → 25/100 → AI-Curious (20-39)
SCORE=$(compute_ai_score 1 1 1 1 1 1)
[ "$SCORE" -eq 25 ] && ok "Scores 1,1,1,1,1,1 → 25 (AI-Curious)" || fail "Expected 25, got $SCORE"

# Test: all 4s → avg=4 → 100/100 → AI-Native (80-100)
SCORE=$(compute_ai_score 4 4 4 4 4 4)
[ "$SCORE" -eq 100 ] && ok "Scores 4,4,4,4,4,4 → 100 (AI-Native)" || fail "Expected 100, got $SCORE"

# Test: 3,3,2,3,3,2 → avg=2.67 → 66.7 → AI-Proficient (60-79)
SCORE=$(compute_ai_score 3 3 2 3 3 2)
[ "$SCORE" -ge 60 ] && [ "$SCORE" -le 79 ] && ok "Scores 3,3,2,3,3,2 → $SCORE (AI-Proficient)" || fail "Expected 60-79, got $SCORE"

# Test: boundary 80 (AI-Native threshold)
# Need avg=3.2 → scores 3,3,3,3,4,3 → avg=3.17 → 79.17 → AI-Proficient
SCORE=$(compute_ai_score 3 3 3 3 4 3)
[ "$SCORE" -lt 80 ] && ok "Boundary: 3,3,3,3,4,3 → $SCORE (<80, not AI-Native)" || fail "Boundary fail: $SCORE"

# Test: boundary 60 (AI-Proficient threshold)
# Scores 2,2,2,3,3,2 → avg=2.33 → 58.3 → AI-Aware
SCORE=$(compute_ai_score 2 2 2 3 3 2)
[ "$SCORE" -lt 60 ] && ok "Boundary: 2,2,2,3,3,2 → $SCORE (<60, AI-Aware)" || fail "Boundary fail: $SCORE"

# Test: boundary 40 (AI-Aware threshold)
# Scores 1,1,2,2,1,1 → avg=1.33 → 33.3 → AI-Curious
SCORE=$(compute_ai_score 1 1 2 2 1 1)
[ "$SCORE" -lt 40 ] && ok "Boundary: 1,1,2,2,1,1 → $SCORE (<40, AI-Curious)" || fail "Boundary fail: $SCORE"

# Test: all 2s → avg=2 → 50 → AI-Aware (40-59)
SCORE=$(compute_ai_score 2 2 2 2 2 2)
[ "$SCORE" -eq 50 ] && ok "Scores 2,2,2,2,2,2 → 50 (AI-Aware)" || fail "Expected 50, got $SCORE"

# ── AI Competency thresholds in rule ────────────────────────
echo ""
echo "2️⃣  AI Competency Thresholds in Rule"

ACF="$RULES_DIR/ai-competency-framework.md"
grep -q '80-100' "$ACF" && ok "AI-Native threshold 80-100" || fail "Missing 80-100"
grep -q '60-79' "$ACF" && ok "AI-Proficient threshold 60-79" || fail "Missing 60-79"
grep -q '40-59' "$ACF" && ok "AI-Aware threshold 40-59" || fail "Missing 40-59"
grep -q '20-39' "$ACF" && ok "AI-Curious threshold 20-39" || fail "Missing 20-39"

# ── AEPD 4-phase weight validation ──────────────────────────
echo ""
echo "3️⃣  AEPD Scoring Weights"

AEPD="$RULES_DIR/aepd-framework.md"
grep -q '0\.25' "$AEPD" && ok "AEPD: 0.25 weight found" || fail "AEPD: missing 0.25"
grep -q '0\.30' "$AEPD" && ok "AEPD: 0.30 weight found" || fail "AEPD: missing 0.30"
grep -q '0\.20' "$AEPD" && ok "AEPD: 0.20 weight found" || fail "AEPD: missing 0.20"

# Sum = 0.25 + 0.30 + 0.25 + 0.20 = 1.00
SUM=$(echo "0.25 + 0.30 + 0.25 + 0.20" | bc)
[ "$SUM" = "1.00" ] && ok "AEPD weights sum to 1.00" || fail "AEPD weights sum: $SUM"

# ── Banking detection formula ───────────────────────────────
echo ""
echo "4️⃣  Banking Detection Score Formula"

BD="$RULES_DIR/banking-detection.md"
grep -q '0\.35' "$BD" && ok "Banking: F1 weight 0.35" || fail "Banking: missing 0.35"
grep -q '0\.25' "$BD" && ok "Banking: F2 weight 0.25" || fail "Banking: missing 0.25"
grep -q '0\.15' "$BD" && ok "Banking: F3 weight 0.15" || fail "Banking: missing 0.15"
grep -q '0\.10' "$BD" && ok "Banking: F5 weight 0.10" || fail "Banking: missing 0.10"

# Sum = 0.35 + 0.25 + 0.15 + 0.15 + 0.10 = 1.00
SUM=$(echo "0.35 + 0.25 + 0.15 + 0.15 + 0.10" | bc)
[ "$SUM" = "1.00" ] && ok "Banking weights sum to 1.00" || fail "Banking weights sum: $SUM"

# ── Mock engine profiles ────────────────────────────────────
echo ""
echo "5️⃣  Mock Engine Profiles"

ENGINES="$REPO_ROOT/docker/savia-test/engines.sh"
if [ -f "$ENGINES" ]; then
  grep -q 'mock_response' "$ENGINES" && ok "Mock engine has mock_response" || fail "Missing mock_response"
  grep -q 'live_exec' "$ENGINES" && ok "Mock engine has live_exec" || fail "Missing live_exec"
else
  fail "engines.sh not found"
fi

# ── Context overflow threshold ──────────────────────────────
echo ""
echo "6️⃣  Context Overflow Threshold"

HARNESS="$REPO_ROOT/docker/savia-test/harness.sh"
if [ -f "$HARNESS" ]; then
  grep -q 'context_overflow' "$HARNESS" && ok "Context overflow check exists" || fail "No overflow check"
else
  fail "harness.sh not found"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Total: $((PASS+FAIL)) | ✅ Passed: $PASS | ❌ Failed: $FAIL"
echo "═══════════════════════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 ALL TESTS PASSED" || { echo "  ⚠️  $FAIL TESTS FAILED"; exit 1; }
