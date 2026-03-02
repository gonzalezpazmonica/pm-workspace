#!/usr/bin/env bash
# ── test-cross-project.sh ────────────────────────────────────────────────
# Tests for v0.50.0: Cross-Project Intelligence
# ──────────────────────────────────────────────────────────────────────────

set -uo pipefail

PASS=0; FAIL=0; ERRORS=""
pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }
check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.50.0 — Cross-Project Intelligence"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. Portfolio Deps Command"
check_file ".claude/commands/portfolio-deps.md" "portfolio-deps.md exists"
check_content ".claude/commands/portfolio-deps.md" "name: portfolio-deps" "Has correct name"
check_content ".claude/commands/portfolio-deps.md" "Dependency Graph" "Builds dependency graph"
check_content ".claude/commands/portfolio-deps.md" "riesgo" "Analyzes risk"
check_content ".claude/commands/portfolio-deps.md" "hub" "Detects hub projects"
check_content ".claude/commands/portfolio-deps.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 2. Backlog Patterns Command"
check_file ".claude/commands/backlog-patterns.md" "backlog-patterns.md exists"
check_content ".claude/commands/backlog-patterns.md" "name: backlog-patterns" "Has correct name"
check_content ".claude/commands/backlog-patterns.md" "similitud" "Uses similarity analysis"
check_content ".claude/commands/backlog-patterns.md" "Duplicados" "Detects duplicates"
check_content ".claude/commands/backlog-patterns.md" "compartible" "Identifies shared functionality"
check_content ".claude/commands/backlog-patterns.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 3. Org Metrics Command"
check_file ".claude/commands/org-metrics.md" "org-metrics.md exists"
check_content ".claude/commands/org-metrics.md" "name: org-metrics" "Has correct name"
check_content ".claude/commands/org-metrics.md" "DORA" "Includes DORA metrics"
check_content ".claude/commands/org-metrics.md" "Deployment Frequency" "Tracks deployment frequency"
check_content ".claude/commands/org-metrics.md" "rankear" "No team ranking policy"
check_content ".claude/commands/org-metrics.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 4. Cross-Project Search Command"
check_file ".claude/commands/cross-project-search.md" "cross-project-search.md exists"
check_content ".claude/commands/cross-project-search.md" "name: cross-project-search" "Has correct name"
check_content ".claude/commands/cross-project-search.md" "code" "Searches code"
check_content ".claude/commands/cross-project-search.md" "specs" "Searches specs"
check_content ".claude/commands/cross-project-search.md" "decisions" "Searches decisions"
check_content ".claude/commands/cross-project-search.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 5. CLAUDE.md Updates"
check_content "CLAUDE.md" "commands/ (189)" "CLAUDE.md shows 178 commands"
check_content "CLAUDE.md" "portfolio-deps" "CLAUDE.md references /portfolio-deps"
check_content "CLAUDE.md" "backlog-patterns" "CLAUDE.md references /backlog-patterns"
check_content "CLAUDE.md" "org-metrics" "CLAUDE.md references /org-metrics"
check_content "CLAUDE.md" "cross-project-search" "CLAUDE.md references /cross-project-search"
echo ""

echo "📋 6. README Updates"
check_content "README.md" "189 comandos" "README.md shows 178 commands"
check_content "README.md" "portfolio-deps" "README.md references /portfolio-deps"
check_content "README.en.md" "189 commands" "README.en.md shows 178 commands"
check_content "README.en.md" "portfolio-deps" "README.en.md references /portfolio-deps"
echo ""

echo "📋 7. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "portfolio-deps" "Context-map includes /portfolio-deps"
check_content ".claude/profiles/context-map.md" "cross-project-search" "Context-map includes /cross-project-search"
check_content ".claude/rules/domain/role-workflows.md" "portfolio-deps" "CEO routine uses /portfolio-deps"
check_content ".claude/rules/domain/role-workflows.md" "org-metrics" "CEO routine uses /org-metrics"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.50.0" "CHANGELOG has v0.50.0 entry"
check_content "CHANGELOG.md" "Cross-Project" "CHANGELOG describes cross-project"
check_content "CHANGELOG.md" "compare/v0.49.0...v0.50.0" "CHANGELOG has v0.50.0 link"
echo ""

echo "📋 9. Regression"
check_file ".claude/commands/value-stream-map.md" "value-stream-map still exists (v0.49.0)"
check_file ".claude/commands/tech-radar.md" "tech-radar still exists (v0.48.0)"
check_file ".claude/commands/ceo-report.md" "ceo-report still exists (v0.45.0)"
echo ""

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed"
echo "═══════════════════════════════════════════════════════════════"
if [ "$FAIL" -gt 0 ]; then
  echo ""; echo "  Failures:"; echo -e "$ERRORS"; exit 1
fi
echo ""; echo "  ✅ All tests passed!"; exit 0
