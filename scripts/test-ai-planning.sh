#!/usr/bin/env bash
# ── test-ai-planning.sh ────────────────────────────────────────────────
# Tests for v0.51.0: AI-Powered Planning
# ──────────────────────────────────────────────────────────────────────────

set -o pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.51.0 — AI-Powered Planning"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Sprint Autoplan Command"
check_file ".claude/commands/sprint-autoplan.md" "sprint-autoplan.md exists"
check_content ".claude/commands/sprint-autoplan.md" "name: sprint-autoplan" "Has correct name"
check_content ".claude/commands/sprint-autoplan.md" "Capacidad" "Includes capacity analysis"
check_content ".claude/commands/sprint-autoplan.md" "Backlog" "References backlog"
check_content ".claude/commands/sprint-autoplan.md" "debt" "Includes technical debt budget"
check_content ".claude/commands/sprint-autoplan.md" "Alternativas" "Shows alternatives"
check_content ".claude/commands/sprint-autoplan.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 2. Risk Predict Command"
check_file ".claude/commands/risk-predict.md" "risk-predict.md exists"
check_content ".claude/commands/risk-predict.md" "name: risk-predict" "Has correct name"
check_content ".claude/commands/risk-predict.md" "Burndown" "Analyzes burndown"
check_content ".claude/commands/risk-predict.md" "WIP" "Tracks WIP metrics"
check_content ".claude/commands/risk-predict.md" "Scope creep" "Detects scope creep"
check_content ".claude/commands/risk-predict.md" "probabilidad" "Includes probability analysis"
check_content ".claude/commands/risk-predict.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 3. Meeting Summarize Command"
check_file ".claude/commands/meeting-summarize.md" "meeting-summarize.md exists"
check_content ".claude/commands/meeting-summarize.md" "name: meeting-summarize" "Has correct name"
check_content ".claude/commands/meeting-summarize.md" "Transcri" "Processes transcriptions"
check_content ".claude/commands/meeting-summarize.md" "Action [Ii]tems" "Extracts action items"
check_content ".claude/commands/meeting-summarize.md" "daily" "Handles daily standup"
check_content ".claude/commands/meeting-summarize.md" "retro" "Handles retrospectives"
check_content ".claude/commands/meeting-summarize.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 4. Capacity Forecast Command"
check_file ".claude/commands/capacity-forecast.md" "capacity-forecast.md exists"
check_content ".claude/commands/capacity-forecast.md" "name: capacity-forecast" "Has correct name"
check_content ".claude/commands/capacity-forecast.md" "Capacidad" "Analyzes capacity"
check_content ".claude/commands/capacity-forecast.md" "Demanda" "Includes demand"
check_content ".claude/commands/capacity-forecast.md" "what-if" "Supports scenarios"
check_content ".claude/commands/capacity-forecast.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 5. CLAUDE.md Updates"
# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "sprint-autoplan" "CLAUDE.md references /sprint-autoplan"
check_content "CLAUDE.md" "risk-predict" "CLAUDE.md references /risk-predict"
check_content "CLAUDE.md" "meeting-summarize" "CLAUDE.md references /meeting-summarize"
check_content "CLAUDE.md" "capacity-forecast" "CLAUDE.md references /capacity-forecast"
echo ""

echo "📋 6. README Updates"
check_content "README.md" "comando" "README.md references version"
check_content "README.md" "sprint-autoplan" "README.md references /sprint-autoplan"
check_content "README.en.md" "command"
check_content "README.en.md" "sprint-autoplan" "README.en.md references /sprint-autoplan"
echo ""

echo "📋 7. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "sprint-autoplan" "Context-map includes /sprint-autoplan"
check_content ".claude/profiles/context-map.md" "capacity-forecast" "Context-map includes /capacity-forecast"
check_content ".claude/rules/domain/role-workflows.md" "sprint-autoplan" "PM workflow uses /sprint-autoplan"
check_content ".claude/rules/domain/role-workflows.md" "capacity-forecast" "PM workflow uses /capacity-forecast"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.51.0" "CHANGELOG has v0.51.0 entry"
check_content "CHANGELOG.md" "AI-Powered Planning" "CHANGELOG describes AI-Powered Planning"
check_content "CHANGELOG.md" "compare/v0.50.0...v0.51.0" "CHANGELOG has v0.51.0 link"
echo ""

echo "📋 9. Regression"
check_file ".claude/commands/portfolio-deps.md" "portfolio-deps still exists"
check_file ".claude/commands/value-stream-map.md" "value-stream-map still exists"
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
