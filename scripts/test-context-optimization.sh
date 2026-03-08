#!/bin/bash
# Test: Context Optimization v0.71.0 (Era 13)
# Validates: 8 context-* commands, frontmatter, ≤150 lines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Context Optimization v0.71.0 — Era 13"
echo "═════════════════════════════════════════════════════════════"

TESTS=0
PASSED=0
FAILED=0

test_case() {
  local desc="$1"
  local condition="$2"
  TESTS=$((TESTS + 1))
  if bash -c "$condition"; then
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
for cmd in context-budget context-compress context-defer context-profile context-load context-optimize context-age context-benchmark; do
  test_case "${cmd}.md exists" "[ -f $REPO_ROOT/.claude/commands/${cmd}.md ]"
done

# ── Test 2: YAML frontmatter ────────────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter"
for cmd in context-budget context-compress context-defer context-profile context-load context-optimize context-age context-benchmark; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
done

# ── Test 3: Line count ≤ 150 ────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines)"
for cmd in context-budget context-compress context-defer context-profile context-load context-optimize context-age context-benchmark; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "context-budget mentions budget\|tokens" "grep -q -i 'budget\|tokens' $REPO_ROOT/.claude/commands/context-budget.md"
test_case "context-compress mentions compress" "grep -q -i 'compress' $REPO_ROOT/.claude/commands/context-compress.md"
test_case "context-defer mentions defer\|lazy" "grep -q -i 'defer\|lazy' $REPO_ROOT/.claude/commands/context-defer.md"
test_case "context-profile mentions profile\|analyze" "grep -q -i 'profile\|analyze' $REPO_ROOT/.claude/commands/context-profile.md"
test_case "context-load mentions load" "grep -q -i 'load' $REPO_ROOT/.claude/commands/context-load.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "context-optimize registered" "grep -rq 'context-optimize' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"
test_case "context-budget registered" "grep -rq 'context-budget' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"

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
