#!/usr/bin/env bash
# ── test-ai-governance.sh ─────────────────────────────────────────────────────
# Tests for v0.60.0: Enterprise AI Governance
# ──────────────────────────────────────────────────────────────────────────────

set -uo pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.60.0 — Enterprise AI Governance"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Governance Policy Command"
check_file ".claude/commands/governance-policy.md" "governance-policy.md exists"
check_content ".claude/commands/governance-policy.md" "name: governance-policy" "Has correct name"
check_content ".claude/commands/governance-policy.md" "política de gobernanza" "References governance policy"
check_content ".claude/commands/governance-policy.md" "agent: none" "Has agent: none"
echo ""

echo "📋 2. Governance Audit Command"
check_file ".claude/commands/governance-audit.md" "governance-audit.md exists"
check_content ".claude/commands/governance-audit.md" "name: governance-audit" "Has correct name"
check_content ".claude/commands/governance-audit.md" "Auditor.*de cumplimiento" "References audit"
check_content ".claude/commands/governance-audit.md" "agent: task" "Has agent: task"
echo ""

echo "📋 3. Governance Report Command"
check_file ".claude/commands/governance-report.md" "governance-report.md exists"
check_content ".claude/commands/governance-report.md" "name: governance-report" "Has correct name"
check_content ".claude/commands/governance-report.md" "reporte\|informe" "References reporting"
check_content ".claude/commands/governance-report.md" "agent: task" "Has agent: task"
echo ""

echo "📋 4. Governance Certify Command"
check_file ".claude/commands/governance-certify.md" "governance-certify.md exists"
check_content ".claude/commands/governance-certify.md" "name: governance-certify" "Has correct name"
check_content ".claude/commands/governance-certify.md" "certificación" "References certification"
check_content ".claude/commands/governance-certify.md" "agent: task" "Has agent: task"
echo ""

echo "📋 5. Line Count Validation (≤150 lines each)"
POLICY_LINES=$(wc -l < .claude/commands/governance-policy.md)
AUDIT_LINES=$(wc -l < .claude/commands/governance-audit.md)
REPORT_LINES=$(wc -l < .claude/commands/governance-report.md)
CERTIFY_LINES=$(wc -l < .claude/commands/governance-certify.md)

[ "$POLICY_LINES" -le 150 ] && pass "governance-policy.md: $POLICY_LINES lines" || fail "governance-policy.md: $POLICY_LINES lines (> 150)"
[ "$AUDIT_LINES" -le 150 ] && pass "governance-audit.md: $AUDIT_LINES lines" || fail "governance-audit.md: $AUDIT_LINES lines (> 150)"
[ "$REPORT_LINES" -le 150 ] && pass "governance-report.md: $REPORT_LINES lines" || fail "governance-report.md: $REPORT_LINES lines (> 150)"
[ "$CERTIFY_LINES" -le 150 ] && pass "governance-certify.md: $CERTIFY_LINES lines" || fail "governance-certify.md: $CERTIFY_LINES lines (> 150)"
echo ""

echo "📋 6. CLAUDE.md Updates"
# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "governance-policy" "CLAUDE.md references /governance-policy"
check_content "CLAUDE.md" "governance-audit" "CLAUDE.md references /governance-audit"
check_content "CLAUDE.md" "governance-report" "CLAUDE.md references /governance-report"
check_content "CLAUDE.md" "governance-certify" "CLAUDE.md references /governance-certify"
check_content "CLAUDE.md" "Enterprise AI Governance" "CLAUDE.md has Enterprise AI Governance section"
echo ""

echo "📋 7. README Updates"
check_content "README.md" "Gobernanza\|governance" "README.md references governance"
check_content "README.en.md" "governance" "README.en.md references governance"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.60.0" "CHANGELOG has v0.60.0 entry"
check_content "CHANGELOG.md" "Enterprise AI Governance" "CHANGELOG describes governance feature"
check_content "CHANGELOG.md" "governance-policy" "CHANGELOG mentions /governance-policy"
check_content "CHANGELOG.md" "governance-audit" "CHANGELOG mentions /governance-audit"
check_content "CHANGELOG.md" "governance-report" "CHANGELOG mentions /governance-report"
check_content "CHANGELOG.md" "governance-certify" "CHANGELOG mentions /governance-certify"
check_content "CHANGELOG.md" "governance" "CHANGELOG mentions governance changes"
check_content "CHANGELOG.md" "NIST AI RMF\|ISO/IEC 42001\|EU AI Act" "CHANGELOG mentions frameworks"
echo ""

echo "📋 9. Command Structure Validation"
# Check frontmatter
for cmd in governance-policy governance-audit governance-report governance-certify; do
  check_content ".claude/commands/$cmd.md" "^---$" "$cmd.md has frontmatter start"
  check_content ".claude/commands/$cmd.md" "^name:" "$cmd.md has name field"
  check_content ".claude/commands/$cmd.md" "^description:" "$cmd.md has description field"
  check_content ".claude/commands/$cmd.md" "^agent:" "$cmd.md has agent field"
done
echo ""

echo "📋 10. Command Metadata Validation"
check_content ".claude/commands/governance-policy.md" "context_cost: low" "governance-policy has context_cost"
check_content ".claude/commands/governance-audit.md" "context_cost: high" "governance-audit has context_cost"
check_content ".claude/commands/governance-report.md" "context_cost: medium" "governance-report has context_cost"
check_content ".claude/commands/governance-certify.md" "context_cost: high" "governance-certify has context_cost"
echo ""

echo "📋 11. Framework References"
check_content ".claude/commands/governance-policy.md" "NIST\|ISO/IEC 42001" "governance-policy references frameworks"
check_content ".claude/commands/governance-audit.md" "NIST\|Map\|Measure\|Manage" "governance-audit references NIST functions"
check_content ".claude/commands/governance-report.md" "EU AI Act\|NIST\|ISO" "governance-report maps to frameworks"
check_content ".claude/commands/governance-certify.md" "ISO 42001\|EU AI Act\|SOC 2" "governance-certify lists frameworks"
echo ""

echo "📋 12. Context Map Updates"
check_content ".claude/profiles/context-map.md" "governance-policy" "context-map includes governance commands"
check_content ".claude/profiles/context-map.md" "governance-audit" "context-map includes governance-audit"
check_content ".claude/profiles/context-map.md" "governance-report" "context-map includes governance-report"
check_content ".claude/profiles/context-map.md" "governance-certify" "context-map includes governance-certify"
echo ""

echo "📋 13. Role Workflows Updates (CEO/CTO)"
check_content "docs/rules/domain/role-workflows.md" "governance-audit" "role-workflows includes governance-audit"
check_content "docs/rules/domain/role-workflows.md" "governance-report" "role-workflows includes governance-report"
check_content "docs/rules/domain/role-workflows.md" "governance-certify" "role-workflows includes governance-certify"
check_content "docs/rules/domain/role-workflows.md" "Ritual mensual" "role-workflows has monthly ritual"
echo ""

echo "📋 14. Integration Points"
check_content ".claude/commands/governance-policy.md" "company/policies.md" "governance-policy references company policy file"
check_content ".claude/commands/governance-audit.md" "company/policies.md" "governance-audit reads company policy"
check_content ".claude/commands/governance-report.md" "governance-audit" "governance-report uses audit data"
check_content ".claude/commands/governance-certify.md" "governance-report" "governance-certify references report"
echo ""

echo "📋 15. Regression (existing commands)"
check_file ".claude/commands/ai-safety-config.md" "ai-safety-config still exists (v0.58.0)"
check_file ".claude/commands/ai-confidence.md" "ai-confidence still exists (v0.58.0)"
check_file ".claude/commands/ai-incident.md" "ai-incident still exists (v0.58.0)"
check_file ".claude/commands/adoption-assess.md" "adoption-assess still exists (v0.59.0)"
echo ""

echo "📋 16. Test Suite Exists"
[ -f "scripts/test-ai-governance.sh" ] && pass "test-ai-governance.sh exists" || fail "test-ai-governance.sh missing"
echo ""

echo "═══════════════════════════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "  ✅ All $PASS tests passed!"
  exit 0
else
  echo "  ❌ $FAIL test(s) failed, $PASS passed"
  echo ""
  echo "Failed tests:"
  echo -e "$ERRORS"
  exit 1
fi
