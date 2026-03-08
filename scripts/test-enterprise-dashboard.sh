#!/usr/bin/env bash
# ── Test: enterprise-dashboard (Era 41 — Enterprise Reporting & Analytics) ──
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { ((PASS++)); ((TOTAL++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  ❌ $1"; }
check() { if bash -c "$1" > /dev/null 2>&1; then pass "$2"; else fail "$2"; fi; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD="$ROOT/.claude/commands/enterprise-dashboard.md"
RULE="$ROOT/.claude/rules/domain/enterprise-metrics.md"
SKILL="$ROOT/.claude/skills/enterprise-analytics/SKILL.md"

echo "═══════════════════════════════════════════"
echo "  Test: enterprise-dashboard (Era 41, v2.13.1)"
echo "═══════════════════════════════════════════"
echo ""

# ── Section 1: Command file ──────────────────────────────────
echo "📋 Command (enterprise-dashboard.md)"
check "test -f '$CMD'" "Command file exists"
check "[ \$(wc -l < '$CMD') -le 150 ]" "Command ≤ 150 lines"
check "grep -q '^name: enterprise-dashboard' '$CMD'" "Has name in frontmatter"
check "grep -q '^description:' '$CMD'" "Has description in frontmatter"
check "grep -q 'portfolio' '$CMD'" "Documents portfolio subcommand"
check "grep -q 'team-health' '$CMD'" "Documents team-health subcommand"
check "grep -q 'risk-matrix' '$CMD'" "Documents risk-matrix subcommand"
check "grep -q 'forecast' '$CMD'" "Documents forecast subcommand"

# ── Section 2: Domain rule ───────────────────────────────────
echo ""
echo "📐 Domain Rule (enterprise-metrics.md)"
check "test -f '$RULE'" "Rule file exists"
check "[ \$(wc -l < '$RULE') -le 150 ]" "Rule ≤ 150 lines"
check "grep -q '^name: enterprise-metrics' '$RULE'" "Has name in frontmatter"
check "grep -q 'SPACE' '$RULE'" "Documents SPACE framework"
check "grep -q 'Portfolio' '$RULE'" "Documents portfolio aggregation"
check "grep -q 'Monte Carlo' '$RULE'" "Documents forecasting"
check "grep -q 'Satisfaction' '$RULE'" "Documents Satisfaction dimension"
check "grep -q 'Performance' '$RULE'" "Documents Performance dimension"

# ── Section 3: Skill ────────────────────────────────────────
echo ""
echo "🧠 Skill (enterprise-analytics/SKILL.md)"
check "test -f '$SKILL'" "Skill file exists"
check "[ \$(wc -l < '$SKILL') -le 150 ]" "Skill ≤ 150 lines"
check "grep -q '^name: enterprise-analytics' '$SKILL'" "Has name in frontmatter"
check "grep -q 'Flujo 1' '$SKILL'" "Has Flow 1 (portfolio)"
check "grep -q 'Flujo 2' '$SKILL'" "Has Flow 2 (team-health)"
check "grep -q 'Flujo 3' '$SKILL'" "Has Flow 3 (risk-matrix)"
check "grep -q 'Flujo 4' '$SKILL'" "Has Flow 4 (forecast)"
check "grep -q 'Errores' '$SKILL'" "Has error handling section"

# ── Section 4: Cross-references ──────────────────────────────
echo ""
echo "🔗 Cross-references"
check "grep -q 'enterprise-metrics' '$CMD'" "Command → Rule reference"
check "grep -q 'enterprise-analytics' '$CMD'" "Command → Skill reference"
check "grep -q 'enterprise-metrics' '$SKILL'" "Skill → Rule reference"

# ── Section 5: Test script ───────────────────────────────────
echo ""
echo "🧪 Test Script (test-enterprise-dashboard.sh)"
TEST_SCRIPT="$ROOT/scripts/test-enterprise-dashboard.sh"
check "test -f '$TEST_SCRIPT'" "Test script exists"
check "test -x '$TEST_SCRIPT'" "Test script is executable"

echo ""
echo "═══════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 All tests passed!" || echo "  ⚠️  Some tests failed"
exit "$FAIL"
