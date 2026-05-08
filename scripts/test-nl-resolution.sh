#!/bin/bash
set -euo pipefail

# Test suite for NL Command Resolution v1.9.0
PASS=0
FAIL=0
TOTAL=0

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

assert_ok() {
  TOTAL=$((TOTAL+1))
  if eval "$1" >/dev/null 2>&1; then
    PASS=$((PASS+1))
    echo -e "  ${GREEN}✅${NC} $2"
  else
    FAIL=$((FAIL+1))
    echo -e "  ${RED}❌${NC} $2"
  fi
}

assert_fail() {
  TOTAL=$((TOTAL+1))
  if ! eval "$1" >/dev/null 2>&1; then
    PASS=$((PASS+1))
    echo -e "  ${GREEN}✅${NC} $2 (expected fail)"
  else
    FAIL=$((FAIL+1))
    echo -e "  ${RED}❌${NC} $2 (should have failed)"
  fi
}

PROJECT_ROOT=$ROOT
INTENT_CATALOG="${PROJECT_ROOT}/.opencode/commands/references/intent-catalog.md"

echo "═══════════════════════════════════════════════════════════"
echo "  Test Suite — NL Command Resolution (v1.9.0)"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Test Group 1: Intent catalog structure
echo "[Group 1] Intent Catalog Structure"

assert_ok \
  "[ -f '$INTENT_CATALOG' ]" \
  "intent-catalog.md exists at .opencode/commands/references/"

assert_ok \
  "grep -cE '^\| .+\|.+\|.+\|' '$INTENT_CATALOG' | awk '{ if (\$1 >= 50) exit 0; else exit 1 }'" \
  "Catalog contains at least 50 intent patterns"

assert_ok \
  "grep -E '^\| .+\|' '$INTENT_CATALOG' | head -1 | awk -F'|' '{ if (NF >= 5) exit 0; else exit 1 }'" \
  "Entries have 4+ columns (intent | command | confidence | category)"

assert_ok \
  "grep '^|.*|' '$INTENT_CATALOG' | grep -v '^|intent' | awk -F'|' '{ gsub(/^ */, \"\", \$3); if (\$3 !~ /^\//) exit 1 }; END { exit 0 }'" \
  "All commands start with /"

assert_ok \
  "grep '^|.*|' '$INTENT_CATALOG' | grep -v '^|intent' | awk -F'|' '{ gsub(/^ */, \"\", \$4); if (\$4 < 70 || \$4 > 95) { print \$4; exit 1 } }; END { exit 0 }'" \
  "Confidence values are between 70-95"

echo ""
# Test Group 2: NL query command structure
echo "[Group 2] NL Query Command Structure"

NL_QUERY="${PROJECT_ROOT}/.opencode/commands/nl-query.md"

assert_ok \
  "[ -f '$NL_QUERY' ]" \
  "nl-query.md exists"

assert_ok \
  "grep -q 'name: nl-query' '$NL_QUERY'" \
  "nl-query.md has correct frontmatter"

assert_ok \
  "grep -q 'intent-catalog' '$NL_QUERY' || grep -q 'intent catalog' '$NL_QUERY'" \
  "nl-query.md references intent-catalog"

assert_ok \
  "grep -q '\-\-explain' '$NL_QUERY'" \
  "nl-query.md defines --explain subcommand"

assert_ok \
  "grep -q '\-\-learn' '$NL_QUERY'" \
  "nl-query.md defines --learn subcommand"

assert_ok \
  "grep -qE '(80|threshold|confidence)' '$NL_QUERY'" \
  "nl-query.md defines confidence thresholds"

echo ""
# Test Group 3: NL resolution rule
echo "[Group 3] NL Resolution Rule"

RESOLUTION_RULE="${PROJECT_ROOT}/docs/rules/domain/nl-command-resolution.md"

if [ -f "$RESOLUTION_RULE" ]; then
  assert_ok \
    "[ -f '$RESOLUTION_RULE' ]" \
    "nl-command-resolution.md exists"

  assert_ok \
    "grep -q 'intent-catalog' '$RESOLUTION_RULE'" \
    "Rule references intent-catalog"

  assert_ok \
    "grep -qiE '(anti.pattern|restriccion|NUNCA)' '$RESOLUTION_RULE'" \
    "Rule defines anti-patterns section"

  assert_ok \
    "grep -qiE '(rule.17|anti.improvis|improvisar|no cubre)' '$RESOLUTION_RULE'" \
    "Rule respects anti-improvisation principle"
else
  echo -e "  ${RED}❌${NC} nl-command-resolution.md not found (skipping 4 checks)"
  FAIL=$((FAIL+4))
  TOTAL=$((TOTAL+4))
fi

echo ""
# Test Group 4: Coverage
echo "[Group 4] Coverage of Intent Categories"

assert_ok \
  "grep -i 'sprint' '$INTENT_CATALOG'" \
  "Intent catalog covers sprint category"

assert_ok \
  "grep -i 'memory\|search' '$INTENT_CATALOG'" \
  "Intent catalog covers memory category"

assert_ok \
  "grep -iE '(flow|board|savia)' '$INTENT_CATALOG'" \
  "Intent catalog covers flow category"

assert_ok \
  "grep -E '[áéíóú]|^.*[a-z].*español|spanish' -i '$INTENT_CATALOG'" \
  "Intent catalog has both Spanish and English patterns"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Resultado: $PASS/$TOTAL passed ($FAIL failed)"
echo "═══════════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
