#!/usr/bin/env bash
# ── test-company-profile.sh ──────────────────────────────────────────────────
# Tests for v0.54.0: Company Profile
# ──────────────────────────────────────────────────────────────────────────────

set -o pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.54.0 — Company Profile"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Company Setup Command"
check_file ".opencode/commands/company-setup.md" "company-setup.md exists"
check_content ".opencode/commands/company-setup.md" "name: company-setup" "Has correct name"
check_content ".opencode/commands/company-setup.md" "onboarding" "References onboarding"
check_content ".opencode/commands/company-setup.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 2. Company Edit Command"
check_file ".opencode/commands/company-edit.md" "company-edit.md exists"
check_content ".opencode/commands/company-edit.md" "name: company-edit" "Has correct name"
check_content ".opencode/commands/company-edit.md" "edit\|modify" "References edit/modify"
check_content ".opencode/commands/company-edit.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 3. Company Show Command"
check_file ".opencode/commands/company-show.md" "company-show.md exists"
check_content ".opencode/commands/company-show.md" "name: company-show" "Has correct name"
check_content ".opencode/commands/company-show.md" "profile\|resumen" "References profile/resumen"
check_content ".opencode/commands/company-show.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 4. Company Vertical Command"
check_file ".opencode/commands/company-vertical.md" "company-vertical.md exists"
check_content ".opencode/commands/company-vertical.md" "name: company-vertical" "Has correct name"
check_content ".opencode/commands/company-vertical.md" "vertical\|sector\|industria" "References vertical/sector/industria"
check_content ".opencode/commands/company-vertical.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 5. CLAUDE.md Updates"
# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "company-setup" "CLAUDE.md references /company-setup"
check_content "CLAUDE.md" "company-edit" "CLAUDE.md references /company-edit"
check_content "CLAUDE.md" "company-show" "CLAUDE.md references /company-show"
check_content "CLAUDE.md" "company-vertical" "CLAUDE.md references /company-vertical"
echo ""

echo "📋 6. README Updates"
check_content "README.md" "comando" "README.md references version"
check_content "README.md" "company-setup" "README.md references /company-setup"
check_content "README.en.md" "command"
check_content "README.en.md" "company-setup" "README.en.md references /company-setup"
echo ""

echo "📋 7. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "company-setup" "Context-map includes /company-setup"
check_content ".claude/profiles/context-map.md" "company-vertical" "Context-map includes /company-vertical"
check_content "docs/rules/domain/role-workflows.md" "company-show" "Role-workflows includes /company-show"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.54.0" "CHANGELOG has v0.54.0 entry"
check_content "CHANGELOG.md" "Company Profile" "CHANGELOG describes Company Profile"
check_content "CHANGELOG.md" "compare/v0.53.0...v0.54.0" "CHANGELOG has v0.54.0 link"
echo ""

echo "📋 9. Company Profile Directory"
check_file ".claude/profiles/company/.gitkeep" "company profile directory exists"
echo ""

echo "📋 10. Regression"
check_file ".opencode/commands/jira-connect.md" "jira-connect still exists"
check_file ".opencode/commands/mcp-server.md" "mcp-server still exists"
check_file ".opencode/commands/ceo-report.md" "ceo-report still exists"
echo ""

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed"
echo "═══════════════════════════════════════════════════════════════"
if [ "$FAIL" -gt 0 ]; then
  echo ""; echo "  Failures:"; echo -e "$ERRORS"; exit 1
fi
echo ""; echo "  ✅ All tests passed!"; exit 0
