#!/bin/bash
# Test: Verticals v0.71.0 (Era 13)
# Validates: 5 vertical-* commands, frontmatter, ≤150 lines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Verticals v0.71.0 — Era 13"
echo "═════════════════════════════════════════════════════════════"

TESTS=0
PASSED=0
FAILED=0

test_case() {
  local desc="$1"
  local condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    PASSED=$((PASSED + 1))
    echo "  ✅ $desc"
  else
    FAILED=$((FAILED + 1))
    echo "  ❌ $desc"
  fi
}

# ── Test 1: Command files exist ─────────────────────────────────
echo ""
echo "1️⃣  Command Files Exist"
test_case "vertical-education.md exists" "[ -f $REPO_ROOT/.claude/commands/vertical-education.md ]"
test_case "vertical-finance.md exists" "[ -f $REPO_ROOT/.claude/commands/vertical-finance.md ]"
test_case "vertical-healthcare.md exists" "[ -f $REPO_ROOT/.claude/commands/vertical-healthcare.md ]"
test_case "vertical-legal.md exists" "[ -f $REPO_ROOT/.claude/commands/vertical-legal.md ]"
test_case "vertical-propose.md exists" "[ -f $REPO_ROOT/.claude/commands/vertical-propose.md ]"

# ── Test 2: YAML frontmatter ────────────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter"
for cmd in vertical-education vertical-finance vertical-healthcare vertical-legal vertical-propose; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
done

# ── Test 3: Line count ≤ 150 ────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines)"
for cmd in vertical-education vertical-finance vertical-healthcare vertical-legal vertical-propose; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "vertical-education mentions education\|student" "grep -q -i 'education\|student' $REPO_ROOT/.claude/commands/vertical-education.md"
test_case "vertical-finance mentions finance\|compliance" "grep -q -i 'finance\|compliance' $REPO_ROOT/.claude/commands/vertical-finance.md"
test_case "vertical-healthcare mentions health\|medical" "grep -q -i 'health\|medical' $REPO_ROOT/.claude/commands/vertical-healthcare.md"
test_case "vertical-legal mentions legal\|compliance" "grep -q -i 'legal\|compliance' $REPO_ROOT/.claude/commands/vertical-legal.md"
test_case "vertical-propose mentions propose\|vertical" "grep -q -i 'propose\|vertical' $REPO_ROOT/.claude/commands/vertical-propose.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "CLAUDE.md mentions vertical-" "grep -q 'vertical-' $REPO_ROOT/CLAUDE.md"

# ── Summary ─────────────────────────────────────────────────────
echo ""
echo "═════════════════════════════════════════════════════════════"
echo "  TEST SUMMARY"
echo "═════════════════════════════════════════════════════════════"
echo "  Total tests: $TESTS"
echo "  ✅ Passed: $PASSED"
echo "  ❌ Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
  echo "  🎉 ALL TESTS PASSED"
  exit 0
else
  echo "  ⚠️  SOME TESTS FAILED"
  exit 1
fi
