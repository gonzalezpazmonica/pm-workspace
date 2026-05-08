#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# test-scoring-intelligence.sh — Tests for Scoring Intelligence (v2.3.0)
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1"; }
check() { if eval "$1" >/dev/null 2>&1; then pass "$2"; else fail "$2"; fi }

CURVES="$ROOT/docs/rules/domain/scoring-curves.md"
DIFF="$ROOT/.opencode/commands/score-diff.md"
SEV="$ROOT/docs/rules/domain/severity-classification.md"
CLAUDE="$ROOT/CLAUDE.md"
CHANGELOG="$ROOT/CHANGELOG.md"

echo "═══ Testing Scoring Intelligence (v2.3.0) ═══"
echo ""

# ─── Section 1: Scoring Curves Rule ───
echo "Section 1: Scoring Curves (scoring-curves.md)"

check "test -f $CURVES" "File exists"
check "[ \$(wc -l < $CURVES) -le 150 ]" "File ≤ 150 lines"
check "grep -qi 'piecewise\|breakpoint' $CURVES" "Contains piecewise/breakpoint concept"
check "grep -qi 'PR.*size\|lines.*changed' $CURVES" "Contains PR size dimension"
check "grep -qi 'context.*usage\|200K' $CURVES" "Contains context usage dimension"
check "grep -qi 'file.*size\|150' $CURVES" "Contains file size dimension"
check "grep -qi 'velocity\|sprint' $CURVES" "Contains velocity dimension"
check "grep -qi 'coverage\|test' $CURVES" "Contains test coverage dimension"
check "grep -qi 'brier\|confidence\|calibration' $CURVES" "Contains confidence calibration dimension"
check "grep -qi 'SonarSource\|Microsoft\|kimun' $CURVES" "Contains references"
check "grep -qi 'interpolat\|formula' $CURVES" "Contains interpolation formula"

echo ""

# ─── Section 2: Score Diff Command ───
echo "Section 2: Score Diff Command (score-diff.md)"

check "test -f $DIFF" "File exists"
check "[ \$(wc -l < $DIFF) -le 150 ]" "File ≤ 150 lines"
check "grep -qi 'score.diff\|/score:diff' $DIFF" "Contains command name"
check "grep -qi 'usage\|--from\|--to' $DIFF" "Contains usage syntax"
check "grep -qi 'delta\|regression\|improvement' $DIFF" "Contains delta tracking"
check "grep -qi 'CRITICAL\|WARNING\|HEALTHY' $DIFF" "Contains severity classification"
check "grep -qi 'output/' $DIFF" "Contains output path"
check "grep -qi 'subagent\|haiku\|model' $DIFF" "Contains subagent config"
check "grep -qi 'scoring-curves\|kimun' $DIFF" "Contains references"

echo ""

# ─── Section 3: Severity Classification Rule ───
echo "Section 3: Severity Classification (severity-classification.md)"

check "test -f $SEV" "File exists"
check "[ \$(wc -l < $SEV) -le 150 ]" "File ≤ 150 lines"
check "grep -qi 'rule of three' $SEV" "Contains Rule of Three concept"
check "grep -qi 'CRITICAL' $SEV" "Contains CRITICAL level"
check "grep -qi 'WARNING' $SEV" "Contains WARNING level"
check "grep -qi 'INFO' $SEV" "Contains INFO level"
check "grep -qi 'PR.*quality\|files.*changed' $SEV" "Contains PR quality thresholds"
check "grep -qi 'sprint.*health\|velocity' $SEV" "Contains sprint health thresholds"
check "grep -qi 'context.*health\|context.*usage' $SEV" "Contains context health thresholds"
check "grep -qi 'code.*quality\|complexity' $SEV" "Contains code quality thresholds"
check "grep -qi 'escalat' $SEV" "Contains escalation protocol"
check "grep -qi 'temporal\|consecutive' $SEV" "Contains temporal escalation"
check "grep -qi 'kimun\|SonarQube' $SEV" "Contains references"

echo ""

# ─── Section 4: Integration ───
echo "Section 4: Integration & Documentation"

check "grep -qi '2\.3\.0' $CHANGELOG" "CHANGELOG contains v2.3.0"
check "grep -qi 'scoring\|curves\|severity' $CHANGELOG" "CHANGELOG describes scoring features"
check "grep -qi 'kimun' $CHANGELOG" "CHANGELOG credits kimun"

echo ""

# ─── Section 5: Cross-references ───
echo "Section 5: Cross-references"

check "grep -qi 'scoring-curves' $DIFF" "score-diff references scoring-curves"
check "grep -qi 'scoring-curves' $SEV" "severity references scoring-curves"
check "grep -qi 'severity\|rule of three\|CRITICAL' $DIFF" "score-diff references severity"

echo ""
echo "═══ Scoring Intelligence: $PASS/$TOTAL passed ═══"

if [ "$FAIL" -gt 0 ]; then exit 1; fi
