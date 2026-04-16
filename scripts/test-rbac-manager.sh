#!/usr/bin/env bash
# ── Test: rbac-manager (Era 37 — RBAC File-Based) ──
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { ((PASS++)); ((TOTAL++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  ❌ $1"; }
check() { if eval "$1" > /dev/null 2>&1; then pass "$2"; else fail "$2"; fi; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD="$ROOT/.claude/commands/rbac-manager.md"
RULE="$ROOT/docs/rules/domain/rbac-model.md"
SKILL="$ROOT/.claude/skills/rbac-management/SKILL.md"

echo "═══════════════════════════════════════════"
echo "  Test: rbac-manager (Era 37, v2.12.0)"
echo "═══════════════════════════════════════════"
echo ""

# ── Section 1: Command file ──────────────────────────────
echo "📋 Command (rbac-manager.md)"
check "test -f '$CMD'" "Command file exists"
check "[ \$(wc -l < '$CMD') -le 150 ]" "Command ≤ 150 lines"
check "grep -q '^name: rbac-manager' '$CMD'" "Has name in frontmatter"
check "grep -q '^description:' '$CMD'" "Has description in frontmatter"
check "grep -q 'allowed-tools:' '$CMD'" "Has allowed-tools"
check "grep -q 'model:' '$CMD'" "Has model field"
check "grep -q 'context_cost:' '$CMD'" "Has context_cost field"
check "grep -q 'grant' '$CMD'" "Documents grant subcommand"
check "grep -q 'revoke' '$CMD'" "Documents revoke subcommand"
check "grep -q 'audit' '$CMD'" "Documents audit subcommand"
check "grep -q 'check' '$CMD'" "Documents check subcommand"
check "grep -q 'rbac-model' '$CMD'" "References rbac-model rule"
check "grep -q 'rbac-management' '$CMD'" "References rbac-management skill"
check "grep -q 'team-orchestrator' '$CMD'" "References team-orchestrator integration"

# ── Section 2: Domain rule ───────────────────────────────
echo ""
echo "📐 Domain Rule (rbac-model.md)"
check "test -f '$RULE'" "Rule file exists"
check "[ \$(wc -l < '$RULE') -le 150 ]" "Rule ≤ 150 lines"
check "grep -q '^name: rbac-model' '$RULE'" "Has name in frontmatter"
check "grep -q '^description:' '$RULE'" "Has description in frontmatter"
check "grep -q 'Admin' '$RULE'" "Defines Admin role"
check "grep -q 'PM' '$RULE'" "Defines PM role"
check "grep -q 'Contributor' '$RULE'" "Defines Contributor role"
check "grep -q 'Viewer' '$RULE'" "Defines Viewer role"
check "grep -q 'permission matrix\|permission' '$RULE'" "Defines permission matrix"
check "grep -q 'sprint-plan\|sprint-review' '$RULE'" "Includes sprint commands"
check "grep -q 'backlog-groom\|pbi-create' '$RULE'" "Includes backlog commands"
check "grep -q 'report-executive\|ceo-report' '$RULE'" "Includes reporting commands"
check "grep -q 'pr-review\|spec-generate' '$RULE'" "Includes code commands"
check "grep -q 'infra-create\|azure-pipelines' '$RULE'" "Includes deploy commands"
check "grep -q 'role inheritance\|inherit' '$RULE'" "Documents role inheritance"
check "grep -q 'audit trail\|audit' '$RULE'" "Documents audit trail"
check "grep -q 'scope.*global\|project-specific' '$RULE'" "Documents scope (global/project)"
check "grep -q 'Pre-command hook\|hook' '$RULE'" "Documents enforcement mechanism"

# ── Section 3: Skill ────────────────────────────────────
echo ""
echo "🧠 Skill (rbac-management/SKILL.md)"
check "test -f '$SKILL'" "Skill file exists"
check "[ \$(wc -l < '$SKILL') -le 150 ]" "Skill ≤ 150 lines"
check "grep -q '^name: rbac-management' '$SKILL'" "Has name in frontmatter"
check "grep -q '^description:' '$SKILL'" "Has description in frontmatter"
check "grep -q 'context: fork' '$SKILL'" "Uses fork context"
check "grep -q 'Flujo 1.*Grant' '$SKILL'" "Has Flow 1 (grant)"
check "grep -q 'Flujo 2.*Revoke' '$SKILL'" "Has Flow 2 (revoke)"
check "grep -q 'Flujo 3.*Audit' '$SKILL'" "Has Flow 3 (audit)"
check "grep -q 'Flujo 4.*Check' '$SKILL'" "Has Flow 4 (check)"
check "grep -q 'Errors\|Sección' '$SKILL'" "Has error handling section"
check "grep -q 'Security\|Sección' '$SKILL'" "Has security section"

# ── Section 4: Cross-references ──────────────────────────
echo ""
echo "🔗 Cross-references"
check "grep -q 'rbac-model' '$CMD'" "Command → Rule reference"
check "grep -q 'rbac-management' '$CMD'" "Command → Skill reference"
check "grep -q 'rbac-model' '$SKILL'" "Skill → Rule reference"
check "grep -q 'team-orchestrator' '$CMD'" "Command → team-orchestrator integration"
check "grep -q 'profile-setup' '$CMD'" "Command → profile-setup integration"
check "grep -q 'hook' '$RULE'" "Rule → hook enforcement"

echo ""
echo "═══════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 All tests passed!" || echo "  ⚠️  Some tests failed"
exit "$FAIL"
