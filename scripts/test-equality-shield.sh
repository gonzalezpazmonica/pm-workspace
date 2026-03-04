#!/usr/bin/env bash
# test-equality-shield.sh — Tests for Equality Shield (v2.1.0)
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1"; }
check() { if eval "$1" >/dev/null 2>&1; then pass "$2"; else fail "$2"; fi }
check_not() { if eval "$1" >/dev/null 2>&1; then fail "$2"; else pass "$2"; fi }

RULE="/home/monica/claude/.claude/rules/domain/equality-shield.md"
CMD="/home/monica/claude/.claude/commands/bias-check.md"
DOC="/home/monica/claude/docs/politica-igualdad.md"
CLAUDE="/home/monica/claude/CLAUDE.md"

echo "═══ Testing Equality Shield (v2.1.0) ═══"
echo ""

# ─── Section 1: Domain Rule (equality-shield.md) ───
echo "Section 1: Domain Rule (equality-shield.md)"

check "test -f $RULE" "File exists"
check "[ \$(wc -l < $RULE) -le 150 ]" "File ≤ 150 lines"
check "grep -q 'Equality Shield' $RULE" "Contains Equality Shield header"
check "grep -qi 'vocacional\|vocational' $RULE" "Contains vocational bias section"
check "grep -qi 'tono\|tone' $RULE" "Contains tone bias section"
check "grep -qi 'etiquetado\|labeling' $RULE" "Contains labeling bias section"
check "grep -qi 'experiencia\|experience' $RULE" "Contains experience bias section"
check "grep -qi 'liderazgo\|leadership' $RULE" "Contains leadership bias section"
check "grep -qi 'comunicación\|communication' $RULE" "Contains communication bias section"
check "grep -qi 'contrafác\|counterfactual' $RULE" "Contains counterfactual test section"
check "grep -qi 'inclusivo\|inclusive' $RULE" "Contains inclusive language section"
check "grep -qi 'LLYC' $RULE" "Contains LLYC reference"
check "grep -qi 'Dwivedi' $RULE" "Contains Dwivedi reference"
check "grep -qi 'EMNLP' $RULE" "Contains EMNLP reference"
check "grep -qi 'RANLP' $RULE" "Contains RANLP reference"
check "grep -qi 'pbi.assign\|sprint.review\|spec.generate' $RULE" "Contains sensitive commands"

echo ""

# ─── Section 2: Command (bias-check.md) ───
echo "Section 2: Command (bias-check.md)"

check "test -f $CMD" "File exists"
check "[ \$(wc -l < $CMD) -le 150 ]" "File ≤ 150 lines"
check "grep -qi 'usage\|uso' $CMD" "Contains usage syntax"
check "grep -qi 'asignaci\|assignment' $CMD" "Contains assignment audit step"
check "grep -qi 'tono\|tone' $CMD" "Contains tone audit step"
check "grep -qi 'métric\|metric' $CMD" "Contains metrics audit step"
check "grep -qi 'output\|salida\|resultado' $CMD" "Contains output section"
check "grep -qi 'subagent\|reflection' $CMD" "Contains subagent configuration"

echo ""

# ─── Section 3: Documentation (politica-igualdad.md) ───
echo "Section 3: Documentation (politica-igualdad.md)"

check "test -f $DOC" "File exists"
check "grep -qi 'contexto\|motivación\|context' $DOC" "Contains context/motivation section"
check "grep -qi 'debiasing\|sesgo\|bias' $DOC" "Contains debiasing strategy"
check "grep -qi 'implementación\|implementation\|nivel\|level' $DOC" "Contains implementation levels"
check "grep -qi 'savia' $DOC" "Contains Savia Flow integration"
check "grep -qi 'métric\|metric\|éxito\|success' $DOC" "Contains success metrics"
check "grep -qi 'referencia\|reference\|LLYC' $DOC" "Contains references"

echo ""

# ─── Section 4: CLAUDE.md Integration ───
echo "Section 4: CLAUDE.md Integration"

check "test -f $CLAUDE" "CLAUDE.md exists"
check "grep -q 'Equality Shield' $CLAUDE" "Contains Equality Shield reference"
check "grep -q '23\.' $CLAUDE" "Contains rule 23"
check "[ \$(wc -l < $CLAUDE) -le 150 ]" "CLAUDE.md ≤ 150 lines"
check "grep -q 'equality-shield' $CLAUDE" "References equality-shield.md"

echo ""

# ─── Section 5: Cross-references ───
echo "Section 5: Cross-references"

check "grep -qi 'bias.check\|/bias' $RULE" "equality-shield.md references bias-check"
check "grep -qi 'equality\|igualdad' $CMD" "bias-check.md references equality"
check "grep -qi 'equality\|igualdad' $DOC" "politica-igualdad.md references equality"
check "grep -qi 'equality\|igualdad' /home/monica/claude/CHANGELOG.md" "CHANGELOG mentions Equality Shield"
check "grep -qi 'equality\|igualdad\|bias\|sesgo' /home/monica/claude/README.md" "README mentions equality"

echo ""
echo "═══ Equality Shield: $PASS/$TOTAL passed ═══"

if [ "$FAIL" -gt 0 ]; then exit 1; fi
