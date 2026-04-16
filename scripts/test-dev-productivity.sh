#!/usr/bin/env bash
# ── test-dev-productivity.sh ──────────────────────────────────────────────
# Tests for v0.47.0: Developer Productivity
# ──────────────────────────────────────────────────────────────────────────

set -o pipefail

PASS=0
FAIL=0
ERRORS=""

pass() { ((PASS++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ERRORS+="  ❌ $1\n"; echo "  ❌ $1"; }

check_file() { [ -f "$1" ] && pass "$2" || fail "$2"; }
check_content() { grep -q "$2" "$1" 2>/dev/null && pass "$3" || fail "$3"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🧪 Test Suite: v0.47.0 — Developer Productivity"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "📋 1. My Sprint Command"
check_file ".claude/commands/my-sprint.md" "my-sprint.md exists"
check_content ".claude/commands/my-sprint.md" "name: my-sprint" "Has correct name"
check_content ".claude/commands/my-sprint.md" "Cycle time" "Tracks cycle time"
check_content ".claude/commands/my-sprint.md" "PRs" "Shows PR status"
check_content ".claude/commands/my-sprint.md" "Modo agente" "Has agent mode"
check_content ".claude/commands/my-sprint.md" "comparar rendimiento" "No team comparisons"
echo ""

echo "📋 2. My Focus Command"
check_file ".claude/commands/my-focus.md" "my-focus.md exists"
check_content ".claude/commands/my-focus.md" "name: my-focus" "Has correct name"
check_content ".claude/commands/my-focus.md" "Bloqueante" "Prioritizes blockers"
check_content ".claude/commands/my-focus.md" "Spec SDD" "Loads spec context"
check_content ".claude/commands/my-focus.md" "Agent-notes" "Loads agent-notes"
check_content ".claude/commands/my-focus.md" "Modo agente" "Has agent mode"
check_content ".claude/commands/my-focus.md" "ejecutar comandos sin confirmación" "No auto-execution"
echo ""

echo "📋 3. My Learning Command"
check_file ".claude/commands/my-learning.md" "my-learning.md exists"
check_content ".claude/commands/my-learning.md" "name: my-learning" "Has correct name"
check_content ".claude/commands/my-learning.md" "agent: task" "Uses task agent"
check_content ".claude/commands/my-learning.md" "best practices" "Compares with best practices"
check_content ".claude/commands/my-learning.md" "Lo que haces bien" "Includes strengths"
check_content ".claude/commands/my-learning.md" "compartir resultados" "Private results"
check_content ".claude/commands/my-learning.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 4. Code Patterns Command"
check_file ".claude/commands/code-patterns.md" "code-patterns.md exists"
check_content ".claude/commands/code-patterns.md" "name: code-patterns" "Has correct name"
check_content ".claude/commands/code-patterns.md" "agent: task" "Uses task agent"
check_content ".claude/commands/code-patterns.md" "Repository" "Detects repository pattern"
check_content ".claude/commands/code-patterns.md" "Strategy" "Detects strategy pattern"
check_content ".claude/commands/code-patterns.md" "Modo agente" "Has agent mode"
echo ""

echo "📋 5. CLAUDE.md Updates"
# Dynamically check command count
EXPECTED_COUNT=$(ls -1 ".claude/commands"/*.md 2>/dev/null | wc -l)
if grep -q "commands/ ($EXPECTED_COUNT)" "CLAUDE.md" 2>/dev/null; then
  pass "CLAUDE.md has correct dynamic command count"
else
  fail "CLAUDE.md command count mismatch (expected: $EXPECTED_COUNT)"
fi
check_content "CLAUDE.md" "my-sprint" "CLAUDE.md references /my-sprint"
check_content "CLAUDE.md" "my-focus" "CLAUDE.md references /my-focus"
check_content "CLAUDE.md" "my-learning" "CLAUDE.md references /my-learning"
check_content "CLAUDE.md" "code-patterns" "CLAUDE.md references /code-patterns"
echo ""

echo "📋 6. README Updates"
check_content "README.md" "comando" "README.md references version"
check_content "README.md" "my-sprint" "README.md references /my-sprint"
check_content "README.md" "my-focus" "README.md references /my-focus"
check_content "README.en.md" "command"
check_content "README.en.md" "my-sprint" "README.en.md references /my-sprint"
echo ""

echo "📋 7. Context Map & Workflows"
check_content ".claude/profiles/context-map.md" "my-sprint" "Context-map includes /my-sprint"
check_content ".claude/profiles/context-map.md" "my-focus" "Context-map includes /my-focus"
check_content "docs/rules/domain/role-workflows.md" "my-sprint" "Dev routine uses /my-sprint"
check_content "docs/rules/domain/role-workflows.md" "my-focus" "Dev routine uses /my-focus"
echo ""

echo "📋 8. CHANGELOG"
check_content "CHANGELOG.md" "0.47.0" "CHANGELOG has v0.47.0 entry"
check_content "CHANGELOG.md" "Developer Productivity" "CHANGELOG describes dev productivity"
check_content "CHANGELOG.md" "compare/v0.46.0...v0.47.0" "CHANGELOG has v0.47.0 link"
echo ""

echo "📋 9. Regression"
check_file ".claude/commands/qa-dashboard.md" "qa-dashboard still exists"
check_file ".claude/commands/ceo-report.md" "ceo-report still exists"
check_file ".claude/commands/hub-audit.md" "hub-audit still exists"
echo ""

TOTAL=$((PASS + FAIL))
echo "═══════════════════════════════════════════════════════════════"
echo "  📊 Results: $PASS/$TOTAL passed"
echo "═══════════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo ""; echo "  Failures:"; echo -e "$ERRORS"; exit 1
fi
echo ""; echo "  ✅ All tests passed!"; exit 0
