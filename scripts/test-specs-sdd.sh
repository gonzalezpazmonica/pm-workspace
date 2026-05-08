#!/bin/bash
# Test: Specs & SDD v0.71.0 (Era 13)
# Validates: 7 spec-* commands, frontmatter, ≤150 lines

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Specs & SDD v0.71.0 — Era 13"
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
test_case "spec-design.md exists" "[ -f $REPO_ROOT/.opencode/commands/spec-design.md ]"
test_case "spec-explore.md exists" "[ -f $REPO_ROOT/.opencode/commands/spec-explore.md ]"
test_case "spec-generate.md exists" "[ -f $REPO_ROOT/.opencode/commands/spec-generate.md ]"
test_case "spec-implement.md exists" "[ -f $REPO_ROOT/.opencode/commands/spec-implement.md ]"
test_case "spec-review.md exists" "[ -f $REPO_ROOT/.opencode/commands/spec-review.md ]"
test_case "spec-verify.md exists" "[ -f $REPO_ROOT/.opencode/commands/spec-verify.md ]"
test_case "spec-status.md exists" "[ -f $REPO_ROOT/.opencode/commands/spec-status.md ]"

# ── Test 2: Command header or frontmatter ─────────────────────────
echo ""
echo "2️⃣  Command Header / Frontmatter"
for cmd in spec-design spec-explore spec-generate spec-implement spec-review; do
  file="$REPO_ROOT/.opencode/commands/${cmd}.md"
  test_case "${cmd}: has header or name" "grep -qE '^(name:|# /)' $file"
  test_case "${cmd}: has content (>5 lines)" "[ \$(wc -l < $file) -gt 5 ]"
done

# ── Test 3: Line count ≤ 150 ────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines)"
for cmd in spec-design spec-explore spec-generate spec-implement spec-review; do
  file="$REPO_ROOT/.opencode/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "spec-design mentions design\|spec" "grep -q -i 'design\|spec' $REPO_ROOT/.opencode/commands/spec-design.md"
test_case "spec-explore mentions explore\|discovery" "grep -q -i 'explore\|discovery' $REPO_ROOT/.opencode/commands/spec-explore.md"
test_case "spec-generate mentions generate" "grep -q -i 'generate' $REPO_ROOT/.opencode/commands/spec-generate.md"
test_case "spec-implement mentions implement\|execute" "grep -q -i 'implement\|execute' $REPO_ROOT/.opencode/commands/spec-implement.md"
test_case "spec-review mentions review" "grep -q -i 'review' $REPO_ROOT/.opencode/commands/spec-review.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "CLAUDE.md mentions spec commands" "grep -q 'spec-' $REPO_ROOT/CLAUDE.md"
test_case "CHANGELOG.md has v0.71.0" "grep -q '0.71.0' $REPO_ROOT/CHANGELOG.md"

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
