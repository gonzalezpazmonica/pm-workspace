#!/usr/bin/env bash
# ── Test: team-orchestrator (Era 36 — Multi-Team Coordination) ──
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { ((PASS++)); ((TOTAL++)); echo "  ✅ $1"; }
fail() { ((FAIL++)); ((TOTAL++)); echo "  ❌ $1"; }
check() { if eval "$1" > /dev/null 2>&1; then pass "$2"; else fail "$2"; fi; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD="$ROOT/.claude/commands/team-orchestrator.md"
RULE="$ROOT/docs/rules/domain/team-structure.md"
SKILL="$ROOT/.claude/skills/team-coordination/SKILL.md"

echo "═══════════════════════════════════════════"
echo "  Test: team-orchestrator (Era 36, v2.11.0)"
echo "═══════════════════════════════════════════"
echo ""

# ── Section 1: Command file ──────────────────────────────────
echo "📋 Command (team-orchestrator.md)"
check "test -f '$CMD'" "Command file exists"
check "[ \$(wc -l < '$CMD') -le 150 ]" "Command ≤ 150 lines"
check "grep -q '^name: team-orchestrator' '$CMD'" "Has name in frontmatter"
check "grep -q '^description:' '$CMD'" "Has description in frontmatter"
check "grep -q 'allowed-tools:' '$CMD'" "Has allowed-tools"
check "grep -q 'model:' '$CMD'" "Has model field"
check "grep -q 'context_cost:' '$CMD'" "Has context_cost field"
check "grep -q 'create' '$CMD'" "Documents create subcommand"
check "grep -q 'assign' '$CMD'" "Documents assign subcommand"
check "grep -q 'deps' '$CMD'" "Documents deps subcommand"
check "grep -q 'sync' '$CMD'" "Documents sync subcommand"
check "grep -q 'status' '$CMD'" "Documents status subcommand"
check "grep -q 'team-structure' '$CMD'" "References team-structure rule"
check "grep -q 'team-coordination' '$CMD'" "References team-coordination skill"

# ── Section 2: Domain rule ───────────────────────────────────
echo ""
echo "📐 Domain Rule (team-structure.md)"
check "test -f '$RULE'" "Rule file exists"
check "[ \$(wc -l < '$RULE') -le 150 ]" "Rule ≤ 150 lines"
check "grep -q '^name: team-structure' '$RULE'" "Has name in frontmatter"
check "grep -q '^description:' '$RULE'" "Has description in frontmatter"
check "grep -q 'departments.md' '$RULE'" "Documents departments index"
check "grep -q 'team.md' '$RULE'" "Documents team.md schema"
check "grep -q 'deps.md' '$RULE'" "Documents deps.md schema"
check "grep -q 'RACI' '$RULE'" "Defines RACI roles"
check "grep -q 'blocking' '$RULE'" "Defines blocking dependency type"
check "grep -q 'informational' '$RULE'" "Defines informational dependency type"
check "grep -q 'shared-resource' '$RULE'" "Defines shared-resource dependency type"
check "grep -q 'escalamiento\|escalation' '$RULE'" "Documents escalation rules"
check "grep -q 'capacity' '$RULE'" "Documents capacity tracking"
check "grep -q 'velocity' '$RULE'" "Documents velocity tracking"
check "grep -q 'Team Topologies\|Skelton' '$RULE'" "References Team Topologies"
check "grep -q 'Anti-patrones\|anti-pattern' '$RULE'" "Lists anti-patterns"
check "grep -q 'Dependency Health' '$RULE'" "Defines Dependency Health metric"
check "grep -q 'Cross-team WIP' '$RULE'" "Defines Cross-team WIP metric"

# ── Section 3: Skill ────────────────────────────────────────
echo ""
echo "🧠 Skill (team-coordination/SKILL.md)"
check "test -f '$SKILL'" "Skill file exists"
check "[ \$(wc -l < '$SKILL') -le 150 ]" "Skill ≤ 150 lines"
check "grep -q '^name: team-coordination' '$SKILL'" "Has name in frontmatter"
check "grep -q '^description:' '$SKILL'" "Has description in frontmatter"
check "grep -q 'context: fork' '$SKILL'" "Uses fork context"
check "grep -q 'Flujo 1' '$SKILL'" "Has Flow 1 (create)"
check "grep -q 'Flujo 2' '$SKILL'" "Has Flow 2 (assign)"
check "grep -q 'Flujo 3' '$SKILL'" "Has Flow 3 (deps)"
check "grep -q 'Flujo 4' '$SKILL'" "Has Flow 4 (sync)"
check "grep -q 'Flujo 5' '$SKILL'" "Has Flow 5 (status)"
check "grep -q 'Errores' '$SKILL'" "Has error handling section"
check "grep -q 'Seguridad' '$SKILL'" "Has security section"
check "grep -q 'circular' '$SKILL'" "Detects circular dependencies"
check "grep -q 'capacity_total' '$SKILL'" "Tracks total capacity"
check "grep -q 'velocity' '$SKILL'" "Tracks velocity"
check "grep -q 'ASCII' '$SKILL'" "Includes ASCII visualization"

# ── Section 4: Cross-references ──────────────────────────────
echo ""
echo "🔗 Cross-references"
check "grep -q 'team-structure' '$CMD'" "Command → Rule reference"
check "grep -q 'team-coordination' '$CMD'" "Command → Skill reference"
check "grep -q 'team-structure' '$SKILL'" "Skill → Rule reference"
check "grep -q 'portfolio-overview\|portfolio' '$CMD'" "Command → portfolio integration"
check "grep -q 'capacity' '$CMD'" "Command → capacity integration"
check "grep -q 'ceo-report\|ceo' '$CMD'" "Command → CEO report integration"

echo ""
echo "═══════════════════════════════════════════"
echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] && echo "  🎉 All tests passed!" || echo "  ⚠️  Some tests failed"
exit "$FAIL"
