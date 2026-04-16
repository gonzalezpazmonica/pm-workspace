#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# test-ai-labor-impact.sh — Tests for AI Labor Impact Analysis (v2.5.0)
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1"; }
check() { if eval "$1" >/dev/null 2>&1; then pass "$2"; else fail "$2"; fi }

CMD="$ROOT/.claude/commands/ai-exposure-audit.md"
RULE="$ROOT/docs/rules/domain/ai-exposure-metrics.md"
SKILL="$ROOT/.claude/skills/ai-labor-impact/SKILL.md"
AI_COMP="$ROOT/docs/rules/domain/ai-competency-framework.md"
CAP_FORE="$ROOT/.claude/commands/capacity-forecast.md"
ENT_DASH="$ROOT/.claude/commands/enterprise-dashboard.md"
DOC_ES="$ROOT/docs/ai-labor-impact-es.md"
DOC_EN="$ROOT/docs/ai-labor-impact-en.md"

echo "═══ Testing AI Labor Impact Analysis ═══"
echo ""

# ─── Section 1: Command File ───
echo "Section 1: ai-exposure-audit.md (command)"

check "test -f $CMD" "Command file exists"
check "[ \$(wc -l < $CMD) -le 150 ]" "Command ≤ 150 lines"
check "grep -qi 'ai-exposure-audit' $CMD" "Contains command name"
check "grep -qi 'observed.*exposure\|exposure.*observed' $CMD" "Contains observed exposure concept"
check "grep -qi 'theoretical\|teórica' $CMD" "Contains theoretical exposure"
check "grep -qi 'anthropic' $CMD" "References Anthropic research"
check "grep -qi 'reskilling' $CMD" "Contains reskilling concept"
check "grep -qi 'augmentation\|automation' $CMD" "Contains augmentation vs automation"
check "grep -qi 'Restricciones\|NUNCA' $CMD" "Contains restrictions"
check "grep -qi 'modo agente\|Agent' $CMD" "Contains agent mode"
check "grep -qi 'frontmatter\|name:' $CMD" "Has YAML frontmatter"
check "grep -qi '\-\-team\|\-\-role\|\-\-threshold' $CMD" "Contains subcommand options"

echo ""

# ─── Section 2: Rule File ───
echo "Section 2: ai-exposure-metrics.md (rule)"

check "test -f $RULE" "Rule file exists"
check "[ \$(wc -l < $RULE) -le 150 ]" "Rule ≤ 150 lines"
check "grep -qi 'theoretical.*exposure\|TE' $RULE" "Contains Theoretical Exposure metric"
check "grep -qi 'observed.*exposure\|OE' $RULE" "Contains Observed Exposure metric"
check "grep -qi 'adoption.*gap\|AG' $RULE" "Contains Adoption Gap metric"
check "grep -qi 'augmentation.*ratio\|AR' $RULE" "Contains Augmentation Ratio metric"
check "grep -qi 'junior.*hiring.*gap\|JHG' $RULE" "Contains Junior Hiring Gap index"
check "grep -qi '14%' $RULE" "Contains 14% junior decline reference"
check "grep -qi 'cognitive.*routine' $RULE" "Contains task taxonomy"
check "grep -qi 'capacity-forecast' $RULE" "Cross-references capacity-forecast"
check "grep -qi 'ai-competency-framework' $RULE" "Cross-references ai-competency-framework"
check "grep -qi 'Anthropic' $RULE" "References Anthropic source"
check "grep -qi 'O\*NET\|BLS' $RULE" "References labor market sources"

echo ""

# ─── Section 3: Skill File ───
echo "Section 3: ai-labor-impact/SKILL.md (skill)"

check "test -f $SKILL" "Skill file exists"
check "grep -qi 'ai-labor-impact' $SKILL" "Contains skill name"
check "grep -qi 'Flujo 1\|audit' $SKILL" "Contains audit flow"
check "grep -qi 'Flujo 2\|reskilling' $SKILL" "Contains reskilling flow"
check "grep -qi 'Flujo 3\|jhg\|junior' $SKILL" "Contains JHG flow"
check "grep -qi 'Flujo 4\|simulat' $SKILL" "Contains simulation flow"
check "grep -qi 'Errores' $SKILL" "Contains error handling"
check "grep -qi 'Seguridad' $SKILL" "Contains security section"
check "grep -qi 'enterprise-analytics' $SKILL" "References enterprise-analytics dependency"
check "grep -qi 'ai-exposure-metrics\|ai-competency' $SKILL" "References prerequisite rules"

echo ""

# ─── Section 4: Documentation ───
echo "Section 4: Documentation (ES + EN)"

check "test -f $DOC_ES" "Spanish docs exist"
check "test -f $DOC_EN" "English docs exist"
check "grep -qi 'exposición\|exposure' $DOC_ES" "ES docs contain exposure concept"
check "grep -qi 'reskilling' $DOC_ES" "ES docs contain reskilling"
check "grep -qi 'exposure' $DOC_EN" "EN docs contain exposure concept"
check "grep -qi 'reskilling' $DOC_EN" "EN docs contain reskilling"
check "grep -qi 'junior.*hiring\|contratación.*junior' $DOC_ES" "ES docs contain JHG"
check "grep -qi 'junior.*hiring' $DOC_EN" "EN docs contain JHG"
check "grep -qi 'Anthropic' $DOC_ES" "ES docs reference Anthropic"
check "grep -qi 'Anthropic' $DOC_EN" "EN docs reference Anthropic"

echo ""

# ─── Section 5: Cross-references & Integration ───
echo "Section 5: Cross-references"

check "grep -qi 'ai-exposure-metrics' $CMD" "Command references rule"
check "grep -qi 'ai-competency-framework' $CMD" "Command references ai-competency"
check "grep -qi 'capacity-forecast' $RULE" "Rule references capacity-forecast"
check "grep -qi 'enterprise-dashboard' $RULE" "Rule references enterprise-dashboard"
check "grep -qi 'team-skills-matrix' $RULE" "Rule references team-skills-matrix"
check "grep -qi 'burnout-radar' $RULE" "Rule references burnout-radar"

echo ""

# ─── Section 6: Line Count Limits ───
echo "Section 6: Line Count Validation"

CMD_LINES=$(wc -l < "$CMD")
RULE_LINES=$(wc -l < "$RULE")
echo "  ℹ️  Command: $CMD_LINES lines (max 150)"
echo "  ℹ️  Rule: $RULE_LINES lines (max 150)"
check "[ $CMD_LINES -le 150 ]" "Command within 150-line limit"
check "[ $RULE_LINES -le 150 ]" "Rule within 150-line limit"

echo ""
echo "═══ AI Labor Impact: $PASS/$TOTAL passed ═══"

if [ "$FAIL" -gt 0 ]; then exit 1; fi
