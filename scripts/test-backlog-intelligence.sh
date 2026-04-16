#!/usr/bin/env bash
# ── test-backlog-intelligence.sh ──────────────────────────────────────────────
# Tests for v0.56.0: Intelligent Backlog Management
# ──────────────────────────────────────────────────────────────────────────────

set -o pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.56.0 — Intelligent Backlog Management"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Backlog Groom Command"
check_file ".claude/commands/backlog-groom.md" "backlog-groom.md exists"
check_content ".claude/commands/backlog-groom.md" "name: backlog-groom" "Has correct name"
check_content ".claude/commands/backlog-groom.md" "grooming\|obsoletos\|duplicados" "References grooming"
check_content ".claude/commands/backlog-groom.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 2. Backlog Prioritize Command"
check_file ".claude/commands/backlog-prioritize.md" "backlog-prioritize.md exists"
check_content ".claude/commands/backlog-prioritize.md" "name: backlog-prioritize" "Has correct name"
check_content ".claude/commands/backlog-prioritize.md" "RICE\|WSJF\|priorización" "References RICE/WSJF"
check_content ".claude/commands/backlog-prioritize.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 3. Outcome Track Command"
check_file ".claude/commands/outcome-track.md" "outcome-track.md exists"
check_content ".claude/commands/outcome-track.md" "name: outcome-track" "Has correct name"
check_content ".claude/commands/outcome-track.md" "outcomes\|release\|valor" "References outcomes/release"
check_content ".claude/commands/outcome-track.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 4. Stakeholder Align Command"
check_file ".claude/commands/stakeholder-align.md" "stakeholder-align.md exists"
check_content ".claude/commands/stakeholder-align.md" "name: stakeholder-align" "Has correct name"
check_content ".claude/commands/stakeholder-align.md" "conflictos\|stakeholders\|datos" "References conflicts/stakeholders"
check_content ".claude/commands/stakeholder-align.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 5. Command Size Validation (≤150 lines)"
for cmd in backlog-groom backlog-prioritize outcome-track stakeholder-align; do
  lines=$(wc -l < ".claude/commands/${cmd}.md")
  if [ "$lines" -le 150 ]; then
    pass "${cmd}.md: $lines lines (✅ under limit)"
  else
    fail "${cmd}.md: $lines lines (❌ exceeds 150 limit)"
  fi
done
echo ""

echo "📋 6. CLAUDE.md Updates"
# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "backlog-groom" "CLAUDE.md references /backlog-groom"
check_content "CLAUDE.md" "backlog-prioritize" "CLAUDE.md references /backlog-prioritize"
check_content "CLAUDE.md" "outcome-track" "CLAUDE.md references /outcome-track"
check_content "CLAUDE.md" "stakeholder-align" "CLAUDE.md references /stakeholder-align"
echo ""

echo "📋 7. README Updates"
check_content "README.md" "comando" "README.md references version"
check_content "README.md" "backlog-groom" "README.md references /backlog-groom"
check_content "README.en.md" "command"
check_content "README.en.md" "backlog-groom" "README.en.md references /backlog-groom"
echo ""

echo "📋 8. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "backlog-groom" "Context-map includes backlog-groom command"
check_content ".claude/profiles/context-map.md" "backlog-groom" "Context-map includes /backlog-groom"
check_content ".claude/profiles/context-map.md" "backlog-prioritize" "Context-map includes /backlog-prioritize"
check_content "docs/rules/domain/role-workflows.md" "backlog-groom" "Role-workflows includes /backlog-groom"
check_content "docs/rules/domain/role-workflows.md" "backlog-prioritize" "Role-workflows includes /backlog-prioritize"
check_content "docs/rules/domain/role-workflows.md" "outcome-track" "Role-workflows includes /outcome-track"
echo ""

echo "📋 9. CHANGELOG"
check_content "CHANGELOG.md" "0.56.0" "CHANGELOG has v0.56.0 entry"
check_content "CHANGELOG.md" "Intelligent Backlog" "CHANGELOG describes Intelligent Backlog"
check_content "CHANGELOG.md" "backlog-groom" "CHANGELOG mentions /backlog-groom"
echo ""

echo "📋 10. Regression — Previous Versions Still Present"
check_file ".claude/commands/okr-define.md" "okr-define still exists"
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
