#!/usr/bin/env bash
# ── test-ai-adoption.sh ────────────────────────────────────────────────────────
# Tests for v0.59.0: AI Adoption Companion
# ──────────────────────────────────────────────────────────────────────────────

set -uo pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.59.0 — AI Adoption Companion"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Adoption Assess Command"
check_file ".claude/commands/adoption-assess.md" "adoption-assess.md exists"
check_content ".claude/commands/adoption-assess.md" "name: adoption-assess" "Has correct name"
check_content ".claude/commands/adoption-assess.md" "ADKAR" "References ADKAR model"
check_content ".claude/commands/adoption-assess.md" "agent: task" "Has agent: task"
echo ""

echo "📋 2. Adoption Plan Command"
check_file ".claude/commands/adoption-plan.md" "adoption-plan.md exists"
check_content ".claude/commands/adoption-plan.md" "name: adoption-plan" "Has correct name"
check_content ".claude/commands/adoption-plan.md" "personalizado" "References personalization"
check_content ".claude/commands/adoption-plan.md" "agent: task" "Has agent: task"
echo ""

echo "📋 3. Adoption Sandbox Command"
check_file ".claude/commands/adoption-sandbox.md" "adoption-sandbox.md exists"
check_content ".claude/commands/adoption-sandbox.md" "name: adoption-sandbox" "Has correct name"
check_content ".claude/commands/adoption-sandbox.md" "sandbox" "References sandbox environment"
check_content ".claude/commands/adoption-sandbox.md" "agent: task" "Has agent: task"
echo ""

echo "📋 4. Adoption Track Command"
check_file ".claude/commands/adoption-track.md" "adoption-track.md exists"
check_content ".claude/commands/adoption-track.md" "name: adoption-track" "Has correct name"
check_content ".claude/commands/adoption-track.md" "métricas" "References metrics"
check_content ".claude/commands/adoption-track.md" "agent: task" "Has agent: task"
echo ""

echo "📋 5. Line Count Validation (≤150 lines each)"
ASSESS_LINES=$(wc -l < .claude/commands/adoption-assess.md)
PLAN_LINES=$(wc -l < .claude/commands/adoption-plan.md)
SANDBOX_LINES=$(wc -l < .claude/commands/adoption-sandbox.md)
TRACK_LINES=$(wc -l < .claude/commands/adoption-track.md)

[ "$ASSESS_LINES" -le 150 ] && pass "adoption-assess.md: $ASSESS_LINES lines" || fail "adoption-assess.md: $ASSESS_LINES lines (> 150)"
[ "$PLAN_LINES" -le 150 ] && pass "adoption-plan.md: $PLAN_LINES lines" || fail "adoption-plan.md: $PLAN_LINES lines (> 150)"
[ "$SANDBOX_LINES" -le 150 ] && pass "adoption-sandbox.md: $SANDBOX_LINES lines" || fail "adoption-sandbox.md: $SANDBOX_LINES lines (> 150)"
[ "$TRACK_LINES" -le 150 ] && pass "adoption-track.md: $TRACK_LINES lines" || fail "adoption-track.md: $TRACK_LINES lines (> 150)"
echo ""

echo "📋 6. Command Count (should be 205)"
TOTAL_COMMANDS=$(ls -1 .claude/commands/*.md | wc -l)
[ "$TOTAL_COMMANDS" -eq 205 ] && pass "Total commands: $TOTAL_COMMANDS" || fail "Total commands: $TOTAL_COMMANDS (expected 205)"
echo ""

echo "📋 7. CLAUDE.md Updates"
check_content "CLAUDE.md" "commands/ (205)" "CLAUDE.md shows 205 commands"
check_content "CLAUDE.md" "adoption-assess" "CLAUDE.md references /adoption-assess"
check_content "CLAUDE.md" "adoption-plan" "CLAUDE.md references /adoption-plan"
check_content "CLAUDE.md" "adoption-sandbox" "CLAUDE.md references /adoption-sandbox"
check_content "CLAUDE.md" "adoption-track" "CLAUDE.md references /adoption-track"
echo ""

echo "📋 8. README Updates"
check_content "README.md" "205 comandos" "README.md shows 205 commands"
check_content "README.md" "adoption-assess" "README.md references /adoption-assess"
check_content "README.md" "adoption-plan" "README.md references /adoption-plan"
check_content "README.md" "adoption-sandbox" "README.md references /adoption-sandbox"
check_content "README.md" "adoption-track" "README.md references /adoption-track"
check_content "README.en.md" "205 commands" "README.en.md shows 205 commands"
echo ""

echo "📋 9. CHANGELOG Updates"
check_content "CHANGELOG.md" "0.59.0" "CHANGELOG has v0.59.0 entry"
check_content "CHANGELOG.md" "AI Adoption Companion" "CHANGELOG describes AI Adoption Companion feature"
check_content "CHANGELOG.md" "adoption-assess" "CHANGELOG mentions /adoption-assess"
check_content "CHANGELOG.md" "adoption-plan" "CHANGELOG mentions /adoption-plan"
check_content "CHANGELOG.md" "adoption-sandbox" "CHANGELOG mentions /adoption-sandbox"
check_content "CHANGELOG.md" "adoption-track" "CHANGELOG mentions /adoption-track"
check_content "CHANGELOG.md" "201 → 205" "CHANGELOG shows command count change"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════════════"
if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failed tests:"
  printf "$ERRORS"
  exit 1
fi
echo ""
echo "✅ All tests passed!"
exit 0
