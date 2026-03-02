#!/bin/bash
# Test: Architecture & Debt v0.71.0 (Era 13)
# Validates: 16 architecture/debt commands, frontmatter, ≤150 lines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Architecture & Debt v0.71.0 — Era 13"
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
for cmd in arch-detect arch-suggest arch-compare arch-fitness arch-recommend arch-health debt-analyze debt-budget debt-prioritize debt-track code-patterns tech-radar dependency-map dependencies-audit legacy-assess adr-create; do
  test_case "${cmd}.md exists" "[ -f $REPO_ROOT/.claude/commands/${cmd}.md ]"
done

# ── Test 2: YAML frontmatter (sample) ────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter (sample)"
for cmd in arch-detect debt-analyze tech-radar legacy-assess; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
done

# ── Test 3: Line count ≤ 150 (sample) ────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines) — sample"
for cmd in arch-detect debt-analyze tech-radar; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "arch-detect mentions architecture\|detect" "grep -q -i 'architecture\|detect' $REPO_ROOT/.claude/commands/arch-detect.md"
test_case "debt-analyze mentions debt\|technical" "grep -q -i 'debt\|technical' $REPO_ROOT/.claude/commands/debt-analyze.md"
test_case "tech-radar mentions tech\|radar" "grep -q -i 'tech\|radar' $REPO_ROOT/.claude/commands/tech-radar.md"
test_case "legacy-assess mentions legacy\|assess" "grep -q -i 'legacy\|assess' $REPO_ROOT/.claude/commands/legacy-assess.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "arch-detect registered" "grep -rq 'arch-detect' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"
test_case "debt-analyze registered" "grep -rq 'debt-analyze' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"

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
