#!/usr/bin/env bash
# ── test-vertical-compliance.sh ────────────────────────────────────────────────
# Tests for v0.61.0: Vertical Compliance Extensions
# ──────────────────────────────────────────────────────────────────────────────

set -uo pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.61.0 — Vertical Compliance Extensions"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Vertical Healthcare Command"
check_file ".claude/commands/vertical-healthcare.md" "vertical-healthcare.md exists"
check_content ".claude/commands/vertical-healthcare.md" "name: vertical-healthcare" "Has correct name"
check_content ".claude/commands/vertical-healthcare.md" "HIPAA\|HL7 FHIR\|FDA 21 CFR" "References healthcare regs"
check_content ".claude/commands/vertical-healthcare.md" "agent: task" "Has agent: task"
check_content ".claude/commands/vertical-healthcare.md" "context_cost: high" "Has high context cost"
echo ""

echo "📋 2. Vertical Finance Command"
check_file ".claude/commands/vertical-finance.md" "vertical-finance.md exists"
check_content ".claude/commands/vertical-finance.md" "name: vertical-finance" "Has correct name"
check_content ".claude/commands/vertical-finance.md" "SOX\|Basel III\|MiFID II\|PCI DSS" "References finance regs"
check_content ".claude/commands/vertical-finance.md" "agent: task" "Has agent: task"
check_content ".claude/commands/vertical-finance.md" "context_cost: high" "Has high context cost"
echo ""

echo "📋 3. Vertical Legal Command"
check_file ".claude/commands/vertical-legal.md" "vertical-legal.md exists"
check_content ".claude/commands/vertical-legal.md" "name: vertical-legal" "Has correct name"
check_content ".claude/commands/vertical-legal.md" "GDPR\|eDiscovery\|contract lifecycle" "References legal regs"
check_content ".claude/commands/vertical-legal.md" "agent: task" "Has agent: task"
check_content ".claude/commands/vertical-legal.md" "context_cost: high" "Has high context cost"
echo ""

echo "📋 4. Vertical Education Command"
check_file ".claude/commands/vertical-education.md" "vertical-education.md exists"
check_content ".claude/commands/vertical-education.md" "name: vertical-education" "Has correct name"
check_content ".claude/commands/vertical-education.md" "FERPA\|accesibilidad\|COPPA" "References education regs"
check_content ".claude/commands/vertical-education.md" "agent: task" "Has agent: task"
check_content ".claude/commands/vertical-education.md" "context_cost: high" "Has high context cost"
echo ""

echo "📋 5. Line Count Validation (≤150 lines each)"
HC_LINES=$(wc -l < .claude/commands/vertical-healthcare.md)
FI_LINES=$(wc -l < .claude/commands/vertical-finance.md)
LE_LINES=$(wc -l < .claude/commands/vertical-legal.md)
ED_LINES=$(wc -l < .claude/commands/vertical-education.md)

[ "$HC_LINES" -le 150 ] && pass "vertical-healthcare.md: $HC_LINES lines (≤150)" || fail "vertical-healthcare.md: $HC_LINES lines (>150)"
[ "$FI_LINES" -le 150 ] && pass "vertical-finance.md: $FI_LINES lines (≤150)" || fail "vertical-finance.md: $FI_LINES lines (>150)"
[ "$LE_LINES" -le 150 ] && pass "vertical-legal.md: $LE_LINES lines (≤150)" || fail "vertical-legal.md: $LE_LINES lines (>150)"
[ "$ED_LINES" -le 150 ] && pass "vertical-education.md: $ED_LINES lines (≤150)" || fail "vertical-education.md: $ED_LINES lines (>150)"
echo ""

echo "📋 6. Meta Files Updated"
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
check_content "CLAUDE.md" "commands/ ($EXPECTED_COUNT)" "CLAUDE.md updated"
check_content "README.md" "vertical\|Vertical" "README.md mentions verticals"
check_content "README.en.md" "vertical\|Vertical" "README.en.md mentions verticals"
check_content "CHANGELOG.md" "0.61.0" "CHANGELOG.md has v0.61.0 entry"
check_content "CHANGELOG.md" "Vertical" "CHANGELOG.md mentions vertical feature"
echo ""

echo "📋 7. Role Workflows Updated"
check_content "docs/rules/domain/role-workflows.md" "vertical-healthcare" "Role workflows includes vertical-healthcare"
check_content "docs/rules/domain/role-workflows.md" "vertical-finance" "Role workflows includes vertical-finance"
check_content "docs/rules/domain/role-workflows.md" "vertical-legal" "Role workflows includes vertical-legal"
check_content "docs/rules/domain/role-workflows.md" "vertical-education" "Role workflows includes vertical-education"
echo ""

echo "📋 8. Command Count Verification"
ACTUAL_COUNT=$(ls -1 .claude/commands/*.md 2>/dev/null | wc -l)
[ "$ACTUAL_COUNT" -ge 210 ] && pass "Total commands: $ACTUAL_COUNT (≥210)" || fail "Total commands: $ACTUAL_COUNT (expected ≥210)"
echo ""

echo "═══════════════════════════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ ALL TESTS PASSED — v0.61.0 Implementation OK"
  echo "  🎯 Summary: $PASS passed, 0 failed"
else
  echo "  ❌ TESTS FAILED — $FAIL errors found"
  echo "  📋 Summary: $PASS passed, $FAIL failed"
  echo ""
  echo "  Errors:"
  echo -e "$ERRORS"
fi
echo "═══════════════════════════════════════════════════════════════"
echo ""

exit "$FAIL"
