#!/usr/bin/env bash
# ── test-qa-toolkit.sh ────────────────────────────────────────────────────
# Tests for v0.46.0: QA and Testing Toolkit
# ──────────────────────────────────────────────────────────────────────────

set -uo pipefail

PASS=0
FAIL=0
ERRORS=""

pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }

check_file() {
  [ -f "$1" ] && pass "$2" || fail "$2"
}

check_content() {
  grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"
}

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.46.0 — QA and Testing Toolkit"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── 1. QA Dashboard Command ──────────────────────────────────────────────

echo "📋 1. QA Dashboard Command"

check_file ".claude/commands/qa-dashboard.md" "qa-dashboard.md exists"
check_content ".claude/commands/qa-dashboard.md" "name: qa-dashboard" "Has correct frontmatter name"
check_content ".claude/commands/qa-dashboard.md" "Quality Score" "Has quality score"
check_content ".claude/commands/qa-dashboard.md" "Cobertura" "Tracks coverage"
check_content ".claude/commands/qa-dashboard.md" "flaky" "Tracks flaky tests"
check_content ".claude/commands/qa-dashboard.md" "Escape rate" "Tracks escape rate"
check_content ".claude/commands/qa-dashboard.md" "Modo agente" "Has agent mode"
check_content ".claude/commands/qa-dashboard.md" "trend" "Has trend subcommand"
echo ""

# ── 2. QA Regression Plan Command ────────────────────────────────────────

echo "📋 2. QA Regression Plan Command"

check_file ".claude/commands/qa-regression-plan.md" "qa-regression-plan.md exists"
check_content ".claude/commands/qa-regression-plan.md" "name: qa-regression-plan" "Has correct frontmatter name"
check_content ".claude/commands/qa-regression-plan.md" "agent: task" "Uses task agent"
check_content ".claude/commands/qa-regression-plan.md" "Identificar ficheros" "Step: identify changed files"
check_content ".claude/commands/qa-regression-plan.md" "Analizar impacto" "Step: analyze impact"
check_content ".claude/commands/qa-regression-plan.md" "DIRECTO" "Classifies direct coverage"
check_content ".claude/commands/qa-regression-plan.md" "INDIRECTO" "Classifies indirect coverage"
check_content ".claude/commands/qa-regression-plan.md" "Sin cobertura" "Reports uncovered files"
check_content ".claude/commands/qa-regression-plan.md" "Modo agente" "Has agent mode"
echo ""

# ── 3. QA Bug Triage Command ─────────────────────────────────────────────

echo "📋 3. QA Bug Triage Command"

check_file ".claude/commands/qa-bug-triage.md" "qa-bug-triage.md exists"
check_content ".claude/commands/qa-bug-triage.md" "name: qa-bug-triage" "Has correct frontmatter name"
check_content ".claude/commands/qa-bug-triage.md" "Clasificar severidad" "Classifies severity"
check_content ".claude/commands/qa-bug-triage.md" "Detectar duplicados" "Detects duplicates"
check_content ".claude/commands/qa-bug-triage.md" "Sugerir asignación" "Suggests assignment"
check_content ".claude/commands/qa-bug-triage.md" "Critical" "Has critical severity"
check_content ".claude/commands/qa-bug-triage.md" "cerrar o modificar bugs" "Safety: no auto-close"
check_content ".claude/commands/qa-bug-triage.md" "Modo agente" "Has agent mode"
echo ""

# ── 4. Test Plan Generate Command ────────────────────────────────────────

echo "📋 4. Test Plan Generate Command"

check_file ".claude/commands/testplan-generate.md" "testplan-generate.md exists"
check_content ".claude/commands/testplan-generate.md" "name: testplan-generate" "Has correct frontmatter name"
check_content ".claude/commands/testplan-generate.md" "agent: task" "Uses task agent"
check_content ".claude/commands/testplan-generate.md" "Unit" "Includes unit tests"
check_content ".claude/commands/testplan-generate.md" "Integration" "Includes integration tests"
check_content ".claude/commands/testplan-generate.md" "E2E" "Includes E2E tests"
check_content ".claude/commands/testplan-generate.md" "edge case" "Includes edge cases"
check_content ".claude/commands/testplan-generate.md" "Modo agente" "Has agent mode"
check_content ".claude/commands/testplan-generate.md" "escribir tests" "Safety: no auto-write tests"
echo ""

# ── 5. CLAUDE.md Updates ──────────────────────────────────────────────────

echo "📋 5. CLAUDE.md Updates"

check_content "CLAUDE.md" "commands/ (154)" "CLAUDE.md shows 154 commands"
check_content "CLAUDE.md" "qa-dashboard" "CLAUDE.md references /qa-dashboard"
check_content "CLAUDE.md" "qa-regression-plan" "CLAUDE.md references /qa-regression-plan"
check_content "CLAUDE.md" "qa-bug-triage" "CLAUDE.md references /qa-bug-triage"
check_content "CLAUDE.md" "testplan-generate" "CLAUDE.md references /testplan-generate"
echo ""

# ── 6. README Updates ─────────────────────────────────────────────────────

echo "📋 6. README Updates"

check_content "README.md" "154 comandos" "README.md shows 154 commands"
check_content "README.md" "qa-dashboard" "README.md references /qa-dashboard"
check_content "README.md" "qa-regression-plan" "README.md references /qa-regression-plan"
check_content "README.en.md" "154 commands" "README.en.md shows 154 commands"
check_content "README.en.md" "qa-dashboard" "README.en.md references /qa-dashboard"
echo ""

# ── 7. Context Map & Role Workflows ──────────────────────────────────────

echo "📋 7. Context Map & Role Workflows"

check_content ".claude/profiles/context-map.md" "qa-dashboard" "Context-map includes /qa-dashboard"
check_content ".claude/rules/domain/role-workflows.md" "qa-dashboard" "QA routine uses /qa-dashboard"
echo ""

# ── 8. CHANGELOG Updates ─────────────────────────────────────────────────

echo "📋 8. CHANGELOG Updates"

check_content "CHANGELOG.md" "0.46.0" "CHANGELOG has v0.46.0 entry"
check_content "CHANGELOG.md" "QA and Testing" "CHANGELOG describes QA toolkit"
check_content "CHANGELOG.md" "compare/v0.45.0...v0.46.0" "CHANGELOG has v0.46.0 compare link"
echo ""

# ── 9. Cross-version Regression ──────────────────────────────────────────

echo "📋 9. Cross-version Regression"

check_file ".claude/commands/ceo-report.md" "ceo-report still exists (v0.45.0)"
check_file ".claude/commands/hub-audit.md" "hub-audit still exists (v0.44.0)"
check_file ".claude/commands/context-age.md" "context-age still exists (v0.43.0)"
echo ""

# ── Summary ────────────────────────────────────────────────────────────────

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed"
echo "═══════════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "  Failures:"
  echo -e "$ERRORS"
  exit 1
fi

echo ""
echo "  ✅ All tests passed!"
exit 0
