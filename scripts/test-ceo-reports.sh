#!/usr/bin/env bash
# ── test-ceo-reports.sh ───────────────────────────────────────────────────
# Tests for v0.45.0: Executive Reports for Leadership
# ──────────────────────────────────────────────────────────────────────────

set -o pipefail

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
echo "  🧪 Test Suite: v0.45.0 — Executive Reports for Leadership"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── 1. CEO Report Command ────────────────────────────────────────────────

echo "📋 1. CEO Report Command"

check_file ".opencode/commands/ceo-report.md" "ceo-report.md exists"
check_content ".opencode/commands/ceo-report.md" "name: ceo-report" "Has correct frontmatter name"
check_content ".opencode/commands/ceo-report.md" "agent: task" "Uses task agent for heavy processing"
check_content ".opencode/commands/ceo-report.md" "context_cost: high" "Marked as high context cost"
check_content ".opencode/commands/ceo-report.md" "Portfolio Health" "Calculates portfolio health"
check_content ".opencode/commands/ceo-report.md" "Risk Exposure" "Calculates risk exposure"
check_content ".opencode/commands/ceo-report.md" "Team Utilization" "Calculates team utilization"
check_content ".opencode/commands/ceo-report.md" "semáforo" "Has traffic-light scoring"
check_content ".opencode/commands/ceo-report.md" "Resumen ejecutivo" "Report has executive summary"
check_content ".opencode/commands/ceo-report.md" "Recomendaciones de Savia" "Report has Savia recommendations"
check_content ".opencode/commands/ceo-report.md" "Modo agente" "Has agent mode"
check_content ".opencode/commands/ceo-report.md" "inventar datos" "Safety: no fake data"
check_content ".opencode/commands/ceo-report.md" "minimizar riesgos" "Safety: no risk minimization"
check_content ".opencode/commands/ceo-report.md" "format" "Supports format flag"
echo ""

# ── 2. CEO Alerts Command ────────────────────────────────────────────────

echo "📋 2. CEO Alerts Command"

check_file ".opencode/commands/ceo-alerts.md" "ceo-alerts.md exists"
check_content ".opencode/commands/ceo-alerts.md" "name: ceo-alerts" "Has correct frontmatter name"
check_content ".opencode/commands/ceo-alerts.md" "context_cost: medium" "Marked as medium context cost"
check_content ".opencode/commands/ceo-alerts.md" "Sprint health" "Checks sprint health"
check_content ".opencode/commands/ceo-alerts.md" "Team burnout" "Checks team burnout"
check_content ".opencode/commands/ceo-alerts.md" "Technical debt" "Checks debt trends"
check_content ".opencode/commands/ceo-alerts.md" "Security" "Checks security CVEs"
check_content ".opencode/commands/ceo-alerts.md" "Dependencies" "Checks inter-project blocks"
check_content ".opencode/commands/ceo-alerts.md" "CRÍTICA" "Has critical severity"
check_content ".opencode/commands/ceo-alerts.md" "ALTA" "Has high severity"
check_content ".opencode/commands/ceo-alerts.md" "MEDIA" "Has medium severity"
check_content ".opencode/commands/ceo-alerts.md" "alertas operativas" "Excludes operational alerts"
check_content ".opencode/commands/ceo-alerts.md" "Modo agente" "Has agent mode"
check_content ".opencode/commands/ceo-alerts.md" "history" "Has history subcommand"
echo ""

# ── 3. Portfolio Overview Command ────────────────────────────────────────

echo "📋 3. Portfolio Overview Command"

check_file ".opencode/commands/portfolio-overview.md" "portfolio-overview.md exists"
check_content ".opencode/commands/portfolio-overview.md" "name: portfolio-overview" "Has correct frontmatter name"
check_content ".opencode/commands/portfolio-overview.md" "context_cost: medium" "Marked as medium context cost"
check_content ".opencode/commands/portfolio-overview.md" "semáforo" "Has traffic-light table"
check_content ".opencode/commands/portfolio-overview.md" "dependencias" "Shows inter-project dependencies"
check_content ".opencode/commands/portfolio-overview.md" "compact" "Has compact subcommand"
check_content ".opencode/commands/portfolio-overview.md" "deps" "Has deps subcommand"
check_content ".opencode/commands/portfolio-overview.md" "Modo agente" "Has agent mode"
check_content ".opencode/commands/portfolio-overview.md" "detalles técnicos" "No technical details"
echo ""

# ── 4. CLAUDE.md Updates ──────────────────────────────────────────────────

echo "📋 4. CLAUDE.md Updates"

# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "ceo-report" "CLAUDE.md references /ceo-report"
check_content "CLAUDE.md" "ceo-alerts" "CLAUDE.md references /ceo-alerts"
check_content "CLAUDE.md" "portfolio-overview" "CLAUDE.md references /portfolio-overview"
echo ""

# ── 5. README Updates ─────────────────────────────────────────────────────

echo "📋 5. README Updates"

check_content "README.md" "comando" "README.md references version"
check_content "README.md" "ceo-report" "README.md references /ceo-report"
check_content "README.md" "portfolio-overview" "README.md references /portfolio-overview"
check_content "README.md" "nformes ejecutivos" "README.md has executive reports feature"
check_content "README.en.md" "command"
check_content "README.en.md" "ceo-report" "README.en.md references /ceo-report"
check_content "README.en.md" "Executive reports" "README.en.md has executive reports feature"
echo ""

# ── 6. Context Map & Role Workflows ──────────────────────────────────────

echo "📋 6. Context Map & Role Workflows"

check_content ".claude/profiles/context-map.md" "ceo-report" "Context-map includes /ceo-report"
check_content ".claude/profiles/context-map.md" "ceo-alerts" "Context-map includes /ceo-alerts"
check_content ".claude/profiles/context-map.md" "portfolio-overview" "Context-map includes /portfolio-overview"
check_content "docs/rules/domain/role-workflows.md" "ceo-alerts" "CEO routine uses /ceo-alerts"
check_content "docs/rules/domain/role-workflows.md" "portfolio-overview" "CEO routine uses /portfolio-overview"
check_content "docs/rules/domain/role-workflows.md" "ceo-report" "CEO routine uses /ceo-report"
echo ""

# ── 7. CHANGELOG Updates ─────────────────────────────────────────────────

echo "📋 7. CHANGELOG Updates"

check_content "CHANGELOG.md" "0.45.0" "CHANGELOG has v0.45.0 entry"
check_content "CHANGELOG.md" "Executive Reports" "CHANGELOG describes executive reports"
check_content "CHANGELOG.md" "compare/v0.44.0...v0.45.0" "CHANGELOG has v0.45.0 compare link"
echo ""

# ── 8. Cross-version Regression ──────────────────────────────────────────

echo "📋 8. Cross-version Regression"

check_file ".opencode/commands/hub-audit.md" "hub-audit still exists"
check_file ".opencode/commands/context-age.md" "context-age still exists"
check_file ".opencode/commands/health-dashboard.md" "health-dashboard still exists"
check_file ".opencode/commands/daily-routine.md" "daily-routine still exists"
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
