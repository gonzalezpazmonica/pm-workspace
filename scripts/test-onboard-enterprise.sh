#!/usr/bin/env bash
# ── Test: onboard-enterprise (Era 39 — Onboarding at Scale) ──
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { ((PASS++)); ((TOTAL++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  ❌ $1"; }
check() { if eval "$1" > /dev/null 2>&1; then pass "$2"; else fail "$2"; fi; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD="$ROOT/.claude/commands/onboard-enterprise.md"
RULE="$ROOT/.claude/rules/domain/onboarding-enterprise.md"
SKILL="$ROOT/.claude/skills/enterprise-onboarding/SKILL.md"

echo "═══════════════════════════════════════════"
echo "  Test: onboard-enterprise (Era 39, v2.12.2)"
echo "═══════════════════════════════════════════"
echo ""

# ── Section 1: Command file ──────────────────────────────────
echo "📋 Command (onboard-enterprise.md)"
check "test -f '$CMD'" "Command file exists"
check "[ \$(wc -l < '$CMD') -le 150 ]" "Command ≤ 150 lines"
check "grep -q '^name: onboard-enterprise' '$CMD'" "Has name in frontmatter"
check "grep -q '^description:' '$CMD'" "Has description in frontmatter"
check "grep -q 'allowed-tools:' '$CMD'" "Has allowed-tools"
check "grep -q 'model:' '$CMD'" "Has model field"
check "grep -q 'import' '$CMD'" "Documents import subcommand"
check "grep -q 'checklist' '$CMD'" "Documents checklist subcommand"
check "grep -q 'progress' '$CMD'" "Documents progress subcommand"
check "grep -q 'knowledge-transfer' '$CMD'" "Documents knowledge-transfer subcommand"
check "grep -q 'onboarding-enterprise' '$CMD'" "References onboarding-enterprise rule"
check "grep -q 'enterprise-onboarding' '$CMD'" "References enterprise-onboarding skill"

# ── Section 2: Domain rule ───────────────────────────────────
echo ""
echo "📐 Domain Rule (onboarding-enterprise.md)"
check "test -f '$RULE'" "Rule file exists"
check "[ \$(wc -l < '$RULE') -le 150 ]" "Rule ≤ 150 lines"
check "grep -q '^name: onboarding-enterprise' '$RULE'" "Has name in frontmatter"
check "grep -q '^description:' '$RULE'" "Has description in frontmatter"
check "grep -q 'Fase 0' '$RULE'" "Documents Phase 0 (pre-arrival)"
check "grep -q 'Fase 1' '$RULE'" "Documents Phase 1 (day 1)"
check "grep -q 'Fase 2' '$RULE'" "Documents Phase 2 (week 1)"
check "grep -q 'Fase 3' '$RULE'" "Documents Phase 3 (month 1)"
check "grep -q 'CSV' '$RULE'" "Documents CSV schema"
check "grep -q 'role' '$RULE'" "Documents per-role checklists"
check "grep -q 'Knowledge Transfer' '$RULE'" "Documents KT template"
check "grep -q 'Time-to-first-commit' '$RULE'" "Defines success metrics"

# ── Section 3: Skill ────────────────────────────────────────
echo ""
echo "🧠 Skill (enterprise-onboarding/SKILL.md)"
check "test -f '$SKILL'" "Skill file exists"
check "[ \$(wc -l < '$SKILL') -le 150 ]" "Skill ≤ 150 lines"
check "grep -q '^name: enterprise-onboarding' '$SKILL'" "Has name in frontmatter"
check "grep -q '^description:' '$SKILL'" "Has description in frontmatter"
check "grep -q 'context: fork' '$SKILL'" "Uses fork context"
check "grep -q 'Flujo 1' '$SKILL'" "Has Flow 1 (import)"
check "grep -q 'Flujo 2' '$SKILL'" "Has Flow 2 (checklist)"
check "grep -q 'Flujo 3' '$SKILL'" "Has Flow 3 (progress)"
check "grep -q 'Flujo 4' '$SKILL'" "Has Flow 4 (knowledge-transfer)"
check "grep -q 'Flujo 5' '$SKILL'" "Has Flow 5 (sync)"
check "grep -q 'Errores' '$SKILL'" "Has error handling section"
check "grep -q 'Seguridad' '$SKILL'" "Has security section"

# ── Section 4: Cross-references ──────────────────────────────
echo ""
echo "🔗 Cross-references"
check "grep -q 'onboarding-enterprise' '$CMD'" "Command → Rule reference"
check "grep -q 'enterprise-onboarding' '$CMD'" "Command → Skill reference"
check "grep -q 'onboarding-enterprise' '$SKILL'" "Skill → Rule reference"
check "grep -q 'team-orchestrator' '$CMD'" "Command → team-orchestrator integration"
check "grep -q 'team-structure' '$RULE'" "Rule → team-structure reference"

# ── Section 5: Test script ───────────────────────────────────
echo ""
echo "🧪 Test Script (test-onboard-enterprise.sh)"
TEST_SCRIPT="$ROOT/scripts/test-onboard-enterprise.sh"
check "test -f '$TEST_SCRIPT'" "Test script exists"
check "test -x '$TEST_SCRIPT'" "Test script is executable"

echo ""
echo "═══════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 All tests passed!" || echo "  ⚠️  Some tests failed"
exit "$FAIL"
