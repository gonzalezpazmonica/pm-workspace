#!/usr/bin/env bash
# test-sovereignty-audit.sh — Structural tests for Cognitive Sovereignty (Era 35 — v2.10.0)
set -uo pipefail

PASS=0; FAIL=0

pass() { ((PASS+=1)) || true; echo "  ✅ $1"; }
fail() { ((FAIL+=1)) || true; echo "  ❌ $1"; }
check() { if eval "$2" > /dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }

echo "══════════════════════════════════════════"
echo "  Cognitive Sovereignty Tests (Era 35 — v2.10.0)"
echo "══════════════════════════════════════════"

# ── Section 1: Command file ────────────────────────────────────────────────
echo ""
echo "── Section 1: Command file ──"
CMD=".opencode/commands/sovereignty-audit.md"
check "Command exists" "[ -f $CMD ]"
LINES=$(wc -l < "$CMD")
check "Command within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has name in frontmatter" "grep -q '^name:' $CMD"
check "Has description in frontmatter" "grep -q '^description:' $CMD"
check "Has scan subcommand" "grep -q 'sovereignty-audit scan' $CMD"
check "Has report subcommand" "grep -q 'sovereignty-audit report' $CMD"
check "Has exit-plan subcommand" "grep -q 'sovereignty-audit exit-plan' $CMD"
check "Has recommend subcommand" "grep -q 'sovereignty-audit recommend' $CMD"
check "References skill" "grep -q 'sovereignty-auditor/SKILL.md' $CMD"
check "References config rule" "grep -q 'cognitive-sovereignty' $CMD"

# ── Section 2: Domain rule ─────────────────────────────────────────────────
echo ""
echo "── Section 2: Domain rule ──"
RULE="docs/rules/domain/cognitive-sovereignty.md"
check "Config rule exists" "[ -f $RULE ]"
LINES=$(wc -l < "$RULE")
check "Config rule within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has De Nicolás reference" "grep -q 'Nicolás' $RULE"
check "Has D1 Portabilidad" "grep -q 'Portabilidad' $RULE"
check "Has D2 Independencia" "grep -q 'Independencia' $RULE"
check "Has D3 Grafo" "grep -q 'grafo' $RULE"
check "Has D4 Gobernanza" "grep -q 'Gobernanza' $RULE"
check "Has D5 Opcionalidad" "grep -q 'Opcionalidad' $RULE"
check "Has scoring formula" "grep -q 'Score.*D1.*D2' $RULE || grep -q '0.25.*0.25.*0.20' $RULE"
check "Has lock-in evolution table" "grep -q 'Cognitivo' $RULE"
check "Has vendor risk matrix" "grep -q 'Vendor Risk' $RULE"
check "Has alarm signals" "grep -q 'alarma' $RULE || grep -q 'Señales' $RULE"
check "Has sovereignty levels" "grep -q 'Soberanía plena' $RULE"
check "Has governance-audit integration" "grep -q 'governance-audit' $RULE"
check "Has AEPD reference" "grep -q 'AEPD' $RULE"
check "Has EU AI Act reference" "grep -q 'EU AI Act' $RULE"
check "Has Gartner reference" "grep -q 'Gartner' $RULE"

# ── Section 3: Skill ──────────────────────────────────────────────────────
echo ""
echo "── Section 3: Skill ──"
SKILL=".opencode/skills/sovereignty-auditor/SKILL.md"
check "Skill exists" "[ -f $SKILL ]"
LINES=$(wc -l < "$SKILL")
check "Skill within limit ($LINES/150 lines)" "[ $LINES -le 150 ]"
check "Has correct name" "grep -q 'sovereignty-auditor' $SKILL"
check "Has scan flow" "grep -q 'Flujo: Scan' $SKILL"
check "Has report flow" "grep -q 'Flujo: Report' $SKILL"
check "Has exit-plan flow" "grep -q 'Flujo: Exit Plan' $SKILL"
check "Has recommend flow" "grep -q 'Flujo: Recommend' $SKILL"
check "Has D1 analysis" "grep -q 'Portabilidad' $SKILL"
check "Has D2 analysis" "grep -q 'Independencia' $SKILL"
check "Has D3 analysis" "grep -q 'grafo' $SKILL || grep -q 'Protección' $SKILL"
check "Has D4 analysis" "grep -q 'Gobernanza' $SKILL"
check "Has D5 analysis" "grep -q 'Opcionalidad\|salida' $SKILL"
check "Has scoring calculation" "grep -q 'Score.*D1\|0.25.*0.25' $SKILL"
check "Has output path" "grep -q 'output/sovereignty' $SKILL"
check "References config rule" "grep -q 'cognitive-sovereignty' $SKILL"
check "Has emergency mode check" "grep -q 'emergency' $SKILL || grep -q 'Emergency' $SKILL"
check "Has SaviaHub check" "grep -q 'SaviaHub\|savia-hub\|savia_hub' $SKILL"

# ── Section 4: Cross-references ────────────────────────────────────────────
echo ""
echo "── Section 4: Cross-references ──"
check "Skill references config rule" "grep -q 'cognitive-sovereignty' $SKILL"
check "Command references skill" "grep -q 'sovereignty-auditor' $CMD"
check "Command references config rule" "grep -q 'cognitive-sovereignty' $CMD"
check "Rule references governance-audit" "grep -q 'governance-audit' $RULE"
check "Command references governance-audit" "grep -q 'governance-audit' $CMD"
check "Skill references governance-audit" "grep -q 'governance-audit' $SKILL"

echo ""
echo "══════════════════════════════════════════"
echo "  Results: $PASS/$((PASS+FAIL)) passed, $FAIL failed"
echo "══════════════════════════════════════════"
[ "$FAIL" -eq 0 ] || exit 1
