#!/bin/bash
# Test: Governance v0.71.0 (Era 13)
# Validates: 4 governance-* commands, frontmatter, ≤150 lines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Governance v0.71.0 — Era 13"
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
test_case "governance-policy.md exists" "[ -f $REPO_ROOT/.claude/commands/governance-policy.md ]"
test_case "governance-audit.md exists" "[ -f $REPO_ROOT/.claude/commands/governance-audit.md ]"
test_case "governance-report.md exists" "[ -f $REPO_ROOT/.claude/commands/governance-report.md ]"
test_case "governance-certify.md exists" "[ -f $REPO_ROOT/.claude/commands/governance-certify.md ]"

# ── Test 2: YAML frontmatter ────────────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter"
for cmd in governance-policy governance-audit governance-report governance-certify; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
done

# ── Test 3: Line count ≤ 150 ────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines)"
for cmd in governance-policy governance-audit governance-report governance-certify; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "governance-policy mentions policy\|compliance" "grep -q -i 'policy\|compliance' $REPO_ROOT/.claude/commands/governance-policy.md"
test_case "governance-audit mentions audit" "grep -q -i 'audit' $REPO_ROOT/.claude/commands/governance-audit.md"
test_case "governance-report mentions report" "grep -q -i 'report' $REPO_ROOT/.claude/commands/governance-report.md"
test_case "governance-certify mentions certif\|verify" "grep -q -i 'certif\|verify' $REPO_ROOT/.claude/commands/governance-certify.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "CLAUDE.md mentions governance-" "grep -q 'governance-' $REPO_ROOT/CLAUDE.md"

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
