#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# test-frontend-testing.sh — Tests for Frontend Testing Nueva Era
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0
pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ❌ $1"; }
check() { if eval "$1" >/dev/null 2>&1; then pass "$2"; else fail "$2"; fi }

AGENT="$ROOT/.claude/agents/frontend-test-runner.md"
VR_CMD="$ROOT/.claude/commands/visual-regression.md"
SV_CMD="$ROOT/.claude/commands/spec-verify-ui.md"
RULE="$ROOT/docs/rules/domain/frontend-testing.md"
DOC_ES="$ROOT/docs/frontend-testing-nueva-era-es.md"
DOC_EN="$ROOT/docs/frontend-testing-nueva-era-en.md"
PLAN="$ROOT/output/linkedin/plan-frontend-nueva-era.md"
FC_RULE="$ROOT/docs/rules/domain/frontend-components.md"

echo "═══ Testing Frontend Testing Nueva Era ═══"
echo ""

# ─── Section 1: Frontend Test Runner Agent ───
echo "Section 1: frontend-test-runner.md (agent)"

check "test -f $AGENT" "Agent file exists"
check "[ \$(wc -l < $AGENT) -le 150 ]" "Agent ≤ 150 lines"
check "grep -qi 'frontend-test-runner' $AGENT" "Contains agent name"
check "grep -qi 'vitest\|jest' $AGENT" "Contains unit test runners"
check "grep -qi 'playwright' $AGENT" "Contains Playwright E2E"
check "grep -qi 'cypress' $AGENT" "Contains Cypress alternative"
check "grep -qi 'coverage' $AGENT" "Contains coverage verification"
check "grep -qi 'frontend-developer' $AGENT" "References frontend-developer for delegation"
check "grep -qi 'angular' $AGENT" "Supports Angular"
check "grep -qi 'react\|vitest' $AGENT" "Supports React"
check "grep -qi 'NUNCA\|Restricciones' $AGENT" "Contains restrictions"
check "grep -qi 'worktree\|isolation' $AGENT" "Uses worktree isolation"

echo ""

# ─── Section 2: Visual Regression Command ───
echo "Section 2: visual-regression.md (command)"

check "test -f $VR_CMD" "Command file exists"
check "[ \$(wc -l < $VR_CMD) -le 150 ]" "Command ≤ 150 lines"
check "grep -qi 'visual-regression' $VR_CMD" "Contains command name"
check "grep -qi 'playwright' $VR_CMD" "Uses Playwright for screenshots"
check "grep -qi 'pixelmatch' $VR_CMD" "Uses pixelmatch for comparison"
check "grep -qi 'baseline' $VR_CMD" "Contains baseline concept"
check "grep -qi 'breakpoint\|375\|768\|1280\|1920' $VR_CMD" "Contains responsive breakpoints"
check "grep -qi 'mobile.*tablet.*desktop\|mobile\|tablet\|desktop\|wide' $VR_CMD" "Contains breakpoint names"
check "grep -qi '0\.1%\|threshold' $VR_CMD" "Contains diff threshold"
check "grep -qi 'update-baseline' $VR_CMD" "Has baseline update subcommand"
check "grep -qi 'figma-extract\|a11y' $VR_CMD" "Cross-references existing commands"
check "grep -qi 'modo agente\|Agent' $VR_CMD" "Contains agent mode"
check "grep -qi 'NUNCA' $VR_CMD" "Contains restrictions"

echo ""

# ─── Section 3: Spec Verify UI Command ───
echo "Section 3: spec-verify-ui.md (command)"

check "test -f $SV_CMD" "Command file exists"
check "[ \$(wc -l < $SV_CMD) -le 150 ]" "Command ≤ 150 lines"
check "grep -qi 'spec-verify-ui' $SV_CMD" "Contains command name"
check "grep -qi 'props\|Input\|Output' $SV_CMD" "Verifies props/inputs"
check "grep -qi 'ARIA\|aria-' $SV_CMD" "Verifies ARIA attributes"
check "grep -qi 'keyboard\|Tab\|Enter\|Escape' $SV_CMD" "Verifies keyboard navigation"
check "grep -qi 'design.*token\|spacing\|typography' $SV_CMD" "Verifies design tokens"
check "grep -qi 'Default.*Hover.*Focus\|8 estados\|estados' $SV_CMD" "Verifies component states"
check "grep -qi 'conformi' $SV_CMD" "Calculates conformity score"
check "grep -qi 'generate-tests' $SV_CMD" "Has test generation subcommand"
check "grep -qi 'fix' $SV_CMD" "Has auto-fix subcommand"
check "grep -qi 'testing-library' $SV_CMD" "Uses testing-library for generated tests"
check "grep -qi 'frontend-components' $SV_CMD" "References frontend-components rule"
check "grep -qi 'SDD\|spec' $SV_CMD" "References SDD specs"
check "grep -qi 'NUNCA' $SV_CMD" "Contains restrictions"

echo ""

# ─── Section 4: Frontend Testing Rule ───
echo "Section 4: frontend-testing.md (rule)"

check "test -f $RULE" "Rule file exists"
check "[ \$(wc -l < $RULE) -le 150 ]" "Rule ≤ 150 lines"
check "grep -qi 'vitest\|jest' $RULE" "Contains unit test tools"
check "grep -qi 'playwright' $RULE" "Contains Playwright"
check "grep -qi 'pixelmatch' $RULE" "Contains pixelmatch"
check "grep -qi '80%\|coverage' $RULE" "Contains coverage threshold"
check "grep -qi '375\|768\|1280\|1920' $RULE" "Contains breakpoint values"
check "grep -qi 'baseline' $RULE" "Contains baseline structure"
check "grep -qi 'flaky' $RULE" "Addresses flaky tests"
check "grep -qi 'frontend-test-runner\|visual-regression\|spec-verify' $RULE" "Cross-references new components"

echo ""

# ─── Section 5: Documentation ───
echo "Section 5: Documentation (ES + EN)"

check "test -f $DOC_ES" "Spanish docs exist"
check "test -f $DOC_EN" "English docs exist"
check "grep -qi 'playwright' $DOC_ES" "ES docs mention Playwright"
check "grep -qi 'visual.*regression' $DOC_ES" "ES docs cover visual regression"
check "grep -qi 'spec.*verify\|spec.*UI\|verificación' $DOC_ES" "ES docs cover spec verification"
check "grep -qi 'savia\|pm-workspace' $DOC_ES" "ES docs mention pm-workspace/Savia"
check "grep -qi 'playwright' $DOC_EN" "EN docs mention Playwright"
check "grep -qi 'visual.*regression' $DOC_EN" "EN docs cover visual regression"
check "grep -qi 'spec.*verify\|spec.*UI\|verification' $DOC_EN" "EN docs cover spec verification"
check "grep -qi 'savia\|pm-workspace' $DOC_EN" "EN docs mention pm-workspace/Savia"

echo ""

# ─── Section 6: Cross-references ───
echo "Section 6: Cross-references & Integration"

check "grep -qi 'spec-verify-ui' $VR_CMD" "visual-regression references spec-verify-ui"
check "grep -qi 'visual-regression' $SV_CMD" "spec-verify-ui references visual-regression"
check "grep -qi 'qa-dashboard' $VR_CMD" "visual-regression references qa-dashboard"
check "grep -qi 'frontend-components' $SV_CMD" "spec-verify references frontend-components"
check "grep -qi 'figma-extract' $DOC_ES" "ES docs reference figma-extract"
check "grep -qi 'a11y' $DOC_ES" "ES docs reference a11y-audit"
check "grep -qi 'SDD\|spec-driven' $DOC_ES" "ES docs reference SDD"

echo ""

# ─── Section 7: Line Count Validation ───
echo "Section 7: Line Count Validation"

AGENT_L=$(wc -l < "$AGENT")
VR_L=$(wc -l < "$VR_CMD")
SV_L=$(wc -l < "$SV_CMD")
RULE_L=$(wc -l < "$RULE")
echo "  ℹ️  Agent: $AGENT_L lines (max 150)"
echo "  ℹ️  Visual Regression: $VR_L lines (max 150)"
echo "  ℹ️  Spec Verify UI: $SV_L lines (max 150)"
echo "  ℹ️  Rule: $RULE_L lines (max 150)"
check "[ $AGENT_L -le 150 ]" "Agent within limit"
check "[ $VR_L -le 150 ]" "Visual Regression within limit"
check "[ $SV_L -le 150 ]" "Spec Verify UI within limit"
check "[ $RULE_L -le 150 ]" "Rule within limit"

echo ""
echo "═══ Frontend Testing: $PASS/$TOTAL passed ═══"

if [ "$FAIL" -gt 0 ]; then exit 1; fi
