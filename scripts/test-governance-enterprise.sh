#!/usr/bin/env bash
# ── Test: governance-enterprise (Era 40 — Governance & Audit Trail) ──
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { ((PASS++)); ((TOTAL++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  ❌ $1"; }
check() { if bash -c "$1" > /dev/null 2>&1; then pass "$2"; else fail "$2"; fi; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD="$ROOT/.claude/commands/governance-enterprise.md"
RULE1="$ROOT/.claude/rules/domain/audit-trail-schema.md"
RULE2="$ROOT/.claude/rules/domain/governance-enterprise.md"
SKILL="$ROOT/.claude/skills/governance-enterprise/SKILL.md"

echo "═══════════════════════════════════════════"
echo "  Test: governance-enterprise (Era 40, v2.13.0)"
echo "═══════════════════════════════════════════"
echo ""

# ── Section 1: Command file ──────────────────────────────────
echo "📋 Command (governance-enterprise.md)"
check "test -f '$CMD'" "Command file exists"
check "[ \$(wc -l < '$CMD') -le 150 ]" "Command ≤ 150 lines"
check "grep -q '^name: governance-enterprise' '$CMD'" "Has name in frontmatter"
check "grep -q '^description:' '$CMD'" "Has description in frontmatter"
check "grep -q 'audit-trail' '$CMD'" "Documents audit-trail subcommand"
check "grep -q 'compliance-check' '$CMD'" "Documents compliance-check subcommand"
check "grep -q 'decision-registry' '$CMD'" "Documents decision-registry subcommand"
check "grep -q 'certify' '$CMD'" "Documents certify subcommand"

# ── Section 2: Domain rules ───────────────────────────────────
echo ""
echo "📐 Domain Rules"
check "test -f '$RULE1'" "Audit trail schema file exists"
check "[ \$(wc -l < '$RULE1') -le 150 ]" "Audit trail schema ≤ 150 lines"
check "grep -q '^name: audit-trail-schema' '$RULE1'" "Audit trail has name"
check "grep -q 'JSONL' '$RULE1'" "Documents JSONL format"
check "grep -q 'Rotación' '$RULE1'" "Documents rotation policy"
check "grep -q 'Retención' '$RULE1'" "Documents retention policy"

check "test -f '$RULE2'" "Governance file exists"
check "[ \$(wc -l < '$RULE2') -le 150 ]" "Governance ≤ 150 lines"
check "grep -q '^name: governance-enterprise' '$RULE2'" "Governance has name"
check "grep -q 'GDPR' '$RULE2'" "Documents GDPR controls"
check "grep -q 'ISO 27001' '$RULE2'" "Documents ISO controls"
check "grep -q 'EU AI Act' '$RULE2'" "Documents EU AI Act controls"
check "grep -q 'AEPD' '$RULE2'" "Documents AEPD controls"
check "grep -q 'Decision Registry' '$RULE2'" "Documents decision registry"

# ── Section 3: Skill ────────────────────────────────────────
echo ""
echo "🧠 Skill (governance-enterprise/SKILL.md)"
check "test -f '$SKILL'" "Skill file exists"
check "[ \$(wc -l < '$SKILL') -le 150 ]" "Skill ≤ 150 lines"
check "grep -q '^name: governance-enterprise' '$SKILL'" "Has name in frontmatter"
check "grep -q '^description:' '$SKILL'" "Has description in frontmatter"
check "grep -q 'Flujo 1' '$SKILL'" "Has Flow 1 (audit-trail)"
check "grep -q 'Flujo 2' '$SKILL'" "Has Flow 2 (compliance-check)"
check "grep -q 'Flujo 3' '$SKILL'" "Has Flow 3 (decision-registry)"
check "grep -q 'Flujo 4' '$SKILL'" "Has Flow 4 (certify)"
check "grep -q 'Errores' '$SKILL'" "Has error handling section"
check "grep -q 'Seguridad' '$SKILL'" "Has security section"

# ── Section 4: Cross-references ──────────────────────────────
echo ""
echo "🔗 Cross-references"
check "grep -q 'audit-trail-schema' '$CMD'" "Command → Audit schema reference"
check "grep -q 'governance-enterprise' '$CMD'" "Command → Governance rule reference"
check "grep -q 'governance-enterprise' '$SKILL'" "Skill → Governance rule reference"
check "grep -q 'audit-trail-schema' '$SKILL'" "Skill → Audit schema reference"

# ── Section 5: Test script ───────────────────────────────────
echo ""
echo "🧪 Test Script (test-governance-enterprise.sh)"
TEST_SCRIPT="$ROOT/scripts/test-governance-enterprise.sh"
check "test -f '$TEST_SCRIPT'" "Test script exists"
check "test -x '$TEST_SCRIPT'" "Test script is executable"

echo ""
echo "═══════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 All tests passed!" || echo "  ⚠️  Some tests failed"
exit "$FAIL"
