#!/bin/bash
# Test: Security & Compliance v0.71.0 (Era 13)
# Validates: 8 security/compliance commands, frontmatter, ≤150 lines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Security & Compliance v0.71.0 — Era 13"
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
for cmd in security-review security-audit security-alerts credential-scan sbom-generate compliance-scan compliance-fix compliance-report; do
  test_case "${cmd}.md exists" "[ -f $REPO_ROOT/.opencode/commands/${cmd}.md ]"
done

# ── Test 2: YAML frontmatter ────────────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter"
for cmd in security-review security-audit credential-scan compliance-scan; do
  file="$REPO_ROOT/.opencode/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
done

# ── Test 3: Line count ≤ 150 ────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines)"
for cmd in security-review security-audit credential-scan compliance-scan; do
  file="$REPO_ROOT/.opencode/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "security-review mentions review\|security" "grep -q -i 'review\|security' $REPO_ROOT/.opencode/commands/security-review.md"
test_case "security-audit mentions audit" "grep -q -i 'audit' $REPO_ROOT/.opencode/commands/security-audit.md"
test_case "credential-scan mentions credential\|secret" "grep -q -i 'credential\|secret' $REPO_ROOT/.opencode/commands/credential-scan.md"
test_case "compliance-scan mentions compliance" "grep -q -i 'compliance' $REPO_ROOT/.opencode/commands/compliance-scan.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "security-review registered" "grep -rq 'security-review' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"
test_case "compliance-scan registered" "grep -rq 'compliance-scan' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"

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
