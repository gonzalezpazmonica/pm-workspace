#!/bin/bash
# Test Suite for Context Engineering 2.0 Commands (v0.62.0)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "════════════════════════════════════════════════════════════"
echo "  TEST: Context Engineering 2.0 (v0.62.0)"
echo "════════════════════════════════════════════════════════════"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

test_section() {
  echo ""
  echo "→ $1"
}

test_cmd_exists() {
  if [ -f "$1" ]; then
    echo "  ✅ $(basename $1) exists"
    ((TESTS_PASSED++))
  else
    echo "  ❌ $(basename $1) NOT FOUND"
    ((TESTS_FAILED++))
  fi
}

# Section 1: Command Files Exist
test_section "Section 1: Command Files Exist"
test_cmd_exists "$REPO_ROOT/.claude/commands/context-budget.md"
test_cmd_exists "$REPO_ROOT/.claude/commands/context-defer.md"
test_cmd_exists "$REPO_ROOT/.claude/commands/context-profile.md"
test_cmd_exists "$REPO_ROOT/.claude/commands/context-compress.md"

# Section 2: Frontmatter Validation
test_section "Section 2: Frontmatter Validation"
for cmd in context-budget context-defer context-profile context-compress; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  if grep -q "^name: ${cmd}$" "$file" && \
     grep -q "^developer_type: all" "$file" && \
     grep -q "^agent: task" "$file" && \
     grep -q "^context_cost: high" "$file"; then
    echo "  ✅ $cmd frontmatter correct"
    ((TESTS_PASSED++))
  else
    echo "  ❌ $cmd frontmatter incorrect"
    ((TESTS_FAILED++))
  fi
done

# Section 3: Line Count Validation
test_section "Section 3: Line Count Validation (≤ 150 lines)"
for cmd in context-budget context-defer context-profile context-compress; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  count=$(wc -l < "$file")
  if [ "$count" -le 150 ]; then
    echo "  ✅ $cmd: $count lines (≤ 150)"
    ((TESTS_PASSED++))
  else
    echo "  ❌ $cmd: $count lines (exceeds 150)"
    ((TESTS_FAILED++))
  fi
done

# Section 4: Key Concepts
test_section "Section 4: Key Concepts Validation"
if grep -q "tokens" "$REPO_ROOT/.claude/commands/context-budget.md"; then
  echo "  ✅ context-budget contains 'tokens'"
  ((TESTS_PASSED++))
else
  echo "  ❌ context-budget missing 'tokens'"
  ((TESTS_FAILED++))
fi

if grep -q "defer" "$REPO_ROOT/.claude/commands/context-defer.md"; then
  echo "  ✅ context-defer contains 'defer'"
  ((TESTS_PASSED++))
else
  echo "  ❌ context-defer missing 'defer'"
  ((TESTS_FAILED++))
fi

if grep -q "profile" "$REPO_ROOT/.claude/commands/context-profile.md"; then
  echo "  ✅ context-profile contains 'profile'"
  ((TESTS_PASSED++))
else
  echo "  ❌ context-profile missing 'profile'"
  ((TESTS_FAILED++))
fi

if grep -q "compress" "$REPO_ROOT/.claude/commands/context-compress.md"; then
  echo "  ✅ context-compress contains 'compress'"
  ((TESTS_PASSED++))
else
  echo "  ❌ context-compress missing 'compress'"
  ((TESTS_FAILED++))
fi

# Section 5: Integration
test_section "Section 5: Integration References"
if grep -q "context-defer" "$REPO_ROOT/.claude/commands/context-budget.md"; then
  echo "  ✅ context-budget references context-defer"
  ((TESTS_PASSED++))
else
  echo "  ❌ context-budget missing context-defer reference"
  ((TESTS_FAILED++))
fi

# Section 6: Meta Files
test_section "Section 6: Meta Files Updated (213 → 217)"
if grep -q "commands/ (217)" "$REPO_ROOT/CLAUDE.md"; then
  echo "  ✅ CLAUDE.md updated to 217"
  ((TESTS_PASSED++))
else
  echo "  ❌ CLAUDE.md not updated"
  ((TESTS_FAILED++))
fi

if grep -q "217 comandos" "$REPO_ROOT/README.md"; then
  echo "  ✅ README.md updated to 217"
  ((TESTS_PASSED++))
else
  echo "  ❌ README.md not updated"
  ((TESTS_FAILED++))
fi

if grep -q "217 commands" "$REPO_ROOT/README.en.md"; then
  echo "  ✅ README.en.md updated to 217"
  ((TESTS_PASSED++))
else
  echo "  ❌ README.en.md not updated"
  ((TESTS_FAILED++))
fi

if grep -q "0.62.0" "$REPO_ROOT/CHANGELOG.md"; then
  echo "  ✅ CHANGELOG.md has v0.62.0"
  ((TESTS_PASSED++))
else
  echo "  ❌ CHANGELOG.md missing v0.62.0"
  ((TESTS_FAILED++))
fi

# Section 7: role-workflows
test_section "Section 7: role-workflows.md Updated"
if grep -q "context-budget\|context-defer\|context-profile\|context-compress" "$REPO_ROOT/.claude/rules/domain/role-workflows.md"; then
  echo "  ✅ role-workflows.md includes context commands"
  ((TESTS_PASSED++))
else
  echo "  ❌ role-workflows.md missing context commands"
  ((TESTS_FAILED++))
fi

# Section 8: Command Count
test_section "Section 8: Total Command Count = 217"
ACTUAL=$(ls "$REPO_ROOT/.claude/commands/"*.md 2>/dev/null | wc -l)
if [ "$ACTUAL" = "217" ]; then
  echo "  ✅ Command count: $ACTUAL"
  ((TESTS_PASSED++))
else
  echo "  ❌ Command count: $ACTUAL (expected 217)"
  ((TESTS_FAILED++))
fi

# Summary
echo ""
echo "════════════════════════════════════════════════════════════"
printf "${GREEN}PASSED: $TESTS_PASSED${NC} | ${RED}FAILED: $TESTS_FAILED${NC}\n"
echo "════════════════════════════════════════════════════════════"

[ $TESTS_FAILED -eq 0 ] && exit 0 || exit 1
