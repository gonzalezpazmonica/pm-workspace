#!/usr/bin/env bash
# ── Test: scale-optimizer (Era 42 — Scale & Integration Polish) ──
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { ((PASS++)); ((TOTAL++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  ❌ $1"; }
check() { if eval "$1" > /dev/null 2>&1; then pass "$2"; else fail "$2"; fi; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD="$ROOT/.claude/commands/scale-optimizer.md"
RULE="$ROOT/docs/rules/domain/scaling-patterns.md"
SKILL="$ROOT/.claude/skills/scaling-operations/SKILL.md"

echo "═══════════════════════════════════════════"
echo "  Test: scale-optimizer (Era 42, v2.14.0)"
echo "═══════════════════════════════════════════"
echo ""

# ── Section 1: Command file ──────────────────────────────────
echo "📋 Command (scale-optimizer.md)"
check "test -f '$CMD'" "Command file exists"
check "[ \$(wc -l < '$CMD') -le 150 ]" "Command ≤ 150 lines"
check "grep -q '^name: scale-optimizer' '$CMD'" "Has name in frontmatter"
check "grep -q '^description:' '$CMD'" "Has description in frontmatter"
check "grep -q 'analyze' '$CMD'" "Documents analyze subcommand"
check "grep -q 'benchmark' '$CMD'" "Documents benchmark subcommand"
check "grep -q 'recommend' '$CMD'" "Documents recommend subcommand"
check "grep -q 'knowledge-search' '$CMD'" "Documents knowledge-search subcommand"

# ── Section 2: Domain rule ───────────────────────────────────
echo ""
echo "📐 Domain Rule (scaling-patterns.md)"
check "test -f '$RULE'" "Rule file exists"
check "[ \$(wc -l < '$RULE') -le 150 ]" "Rule ≤ 150 lines"
check "grep -q '^name: scaling-patterns' '$RULE'" "Has name in frontmatter"
check "grep -q 'Tier 1' '$RULE'" "Documents Tier 1 (Small)"
check "grep -q 'Tier 2' '$RULE'" "Documents Tier 2 (Medium)"
check "grep -q 'Tier 3' '$RULE'" "Documents Tier 3 (Large)"
check "grep -q 'vendor' '$RULE'" "Documents vendor sync patterns"
check "grep -q 'knowledge search' '$RULE'" "Documents knowledge search"

# ── Section 3: Skill ────────────────────────────────────────
echo ""
echo "🧠 Skill (scaling-operations/SKILL.md)"
check "test -f '$SKILL'" "Skill file exists"
check "[ \$(wc -l < '$SKILL') -le 150 ]" "Skill ≤ 150 lines"
check "grep -q '^name: scaling-operations' '$SKILL'" "Has name in frontmatter"
check "grep -q 'Flujo 1' '$SKILL'" "Has Flow 1 (analyze)"
check "grep -q 'Flujo 2' '$SKILL'" "Has Flow 2 (benchmark)"
check "grep -q 'Flujo 3' '$SKILL'" "Has Flow 3 (recommend)"
check "grep -q 'Flujo 4' '$SKILL'" "Has Flow 4 (knowledge-search)"
check "grep -q 'Errores' '$SKILL'" "Has error handling section"

# ── Section 4: Cross-references ──────────────────────────────
echo ""
echo "🔗 Cross-references"
check "grep -q 'scaling-patterns' '$CMD'" "Command → Rule reference"
check "grep -q 'scaling-operations' '$CMD'" "Command → Skill reference"
check "grep -q 'scaling-patterns' '$SKILL'" "Skill → Rule reference"

# ── Section 5: Test script ───────────────────────────────────
echo ""
echo "🧪 Test Script (test-scale-optimizer.sh)"
TEST_SCRIPT="$ROOT/scripts/test-scale-optimizer.sh"
check "test -f '$TEST_SCRIPT'" "Test script exists"
check "test -x '$TEST_SCRIPT'" "Test script is executable"

echo ""
echo "═══════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 All tests passed!" || echo "  ⚠️  Some tests failed"
exit "$FAIL"
