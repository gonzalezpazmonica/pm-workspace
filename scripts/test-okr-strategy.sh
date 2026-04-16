#!/usr/bin/env bash
# ── test-okr-strategy.sh ──────────────────────────────────────────────────────
# Tests for v0.55.0: OKR & Strategic Alignment
# ──────────────────────────────────────────────────────────────────────────────

set -o pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.55.0 — OKR & Strategic Alignment"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. OKR Define Command"
check_file ".claude/commands/okr-define.md" "okr-define.md exists"
check_content ".claude/commands/okr-define.md" "name: okr-define" "Has correct name"
check_content ".claude/commands/okr-define.md" "Objectives y Key Results" "References OKRs"
check_content ".claude/commands/okr-define.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 2. OKR Track Command"
check_file ".claude/commands/okr-track.md" "okr-track.md exists"
check_content ".claude/commands/okr-track.md" "name: okr-track" "Has correct name"
check_content ".claude/commands/okr-track.md" "Tracking automático" "References tracking"
check_content ".claude/commands/okr-track.md" "Modo agente" "Has agent mode"
check_content ".claude/commands/okr-track.md" "🟢🟡🔴" "References traffic lights"
echo ""

echo "📋 3. OKR Align Command"
check_file ".claude/commands/okr-align.md" "okr-align.md exists"
check_content ".claude/commands/okr-align.md" "name: okr-align" "Has correct name"
check_content ".claude/commands/okr-align.md" "alineación" "References alignment"
check_content ".claude/commands/okr-align.md" "Modo agente" "Has agent mode"
check_content ".claude/commands/okr-align.md" "orphan" "References orphan projects"
echo ""

echo "📋 4. Strategy Map Command"
check_file ".claude/commands/strategy-map.md" "strategy-map.md exists"
check_content ".claude/commands/strategy-map.md" "name: strategy-map" "Has correct name"
check_content ".claude/commands/strategy-map.md" "mapa estratégico" "References strategy map"
check_content ".claude/commands/strategy-map.md" "Modo agente" "Has agent mode"
check_content ".claude/commands/strategy-map.md" "iniciativas" "References initiatives"
echo ""

echo "📋 5. CLAUDE.md Updates"
# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "okr-define" "CLAUDE.md references /okr-define"
check_content "CLAUDE.md" "okr-track" "CLAUDE.md references /okr-track"
check_content "CLAUDE.md" "okr-align" "CLAUDE.md references /okr-align"
check_content "CLAUDE.md" "strategy-map" "CLAUDE.md references /strategy-map"
check_content "CLAUDE.md" "OKR & Strategy" "CLAUDE.md has OKR & Strategy section"
echo ""

echo "📋 6. README Updates"
check_content "README.md" "comando" "README.md references version"
check_content "README.md" "okr-define" "README.md references /okr-define"
check_content "README.md" "okr-track" "README.md references /okr-track"
check_content "README.md" "OKR & Strategy" "README.md has OKR & Strategy section"
check_content "README.en.md" "command"
check_content "README.en.md" "okr-define" "README.en.md references /okr-define"
check_content "README.en.md" "OKR & Strategy" "README.en.md has OKR & Strategy section"
echo ""

echo "📋 7. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "okr-define" "Context-map includes /okr-define"
check_content ".claude/profiles/context-map.md" "okr-track" "Context-map includes /okr-track"
check_content "docs/rules/domain/role-workflows.md" "okr-track" "Role-workflows includes /okr-track"
check_content "docs/rules/domain/role-workflows.md" "okr-align" "Role-workflows includes /okr-align"
check_content "docs/rules/domain/role-workflows.md" "strategy-map" "Role-workflows includes /strategy-map"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.55.0" "CHANGELOG has v0.55.0 entry"
check_content "CHANGELOG.md" "OKR & Strategic Alignment" "CHANGELOG describes OKR & Strategy"
check_content "CHANGELOG.md" "okr-define" "CHANGELOG lists /okr-define"
check_content "CHANGELOG.md" "okr-track" "CHANGELOG lists /okr-track"
check_content "CHANGELOG.md" "okr-align" "CHANGELOG lists /okr-align"
check_content "CHANGELOG.md" "strategy-map" "CHANGELOG lists /strategy-map"
check_content "CHANGELOG.md" "compare/v0.54.0...v0.55.0" "CHANGELOG has v0.55.0 link"
echo ""

echo "📋 9. Regression Tests"
check_file ".claude/commands/company-setup.md" "company-setup still exists"
check_file ".claude/commands/jira-connect.md" "jira-connect still exists"
check_file ".claude/commands/ceo-report.md" "ceo-report still exists"
echo ""

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed"
echo "═══════════════════════════════════════════════════════════════"
if [ "$FAIL" -gt 0 ]; then
  echo ""; echo "  Failures:"; echo -e "$ERRORS"; exit 1
fi
echo ""; echo "  ✅ All tests passed!"; exit 0
