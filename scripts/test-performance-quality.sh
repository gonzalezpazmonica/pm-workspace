#!/bin/bash
# Test: Performance & Quality v0.71.0 (Era 13)
# Validates: 6 performance/quality commands, frontmatter, ≤150 lines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Performance & Quality v0.71.0 — Era 13"
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
test_case "perf-audit.md exists" "[ -f $REPO_ROOT/.claude/commands/perf-audit.md ]"
test_case "perf-fix.md exists" "[ -f $REPO_ROOT/.claude/commands/perf-fix.md ]"
test_case "perf-report.md exists" "[ -f $REPO_ROOT/.claude/commands/perf-report.md ]"
test_case "testplan-generate.md exists" "[ -f $REPO_ROOT/.claude/commands/testplan-generate.md ]"
test_case "testplan-results.md exists" "[ -f $REPO_ROOT/.claude/commands/testplan-results.md ]"
test_case "testplan-status.md exists" "[ -f $REPO_ROOT/.claude/commands/testplan-status.md ]"

# ── Test 2: YAML frontmatter ────────────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter"
for cmd in perf-audit perf-fix perf-report testplan-generate testplan-results testplan-status; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
done

# ── Test 3: Line count ≤ 150 ────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines)"
for cmd in perf-audit perf-fix perf-report testplan-generate; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "perf-audit mentions performance\|audit" "grep -q -i 'performance\|audit' $REPO_ROOT/.claude/commands/perf-audit.md"
test_case "perf-fix mentions fix\|optimize" "grep -q -i 'fix\|optimize' $REPO_ROOT/.claude/commands/perf-fix.md"
test_case "perf-report mentions report" "grep -q -i 'report' $REPO_ROOT/.claude/commands/perf-report.md"
test_case "testplan-generate mentions testplan\|generate" "grep -q -i 'testplan\|generate' $REPO_ROOT/.claude/commands/testplan-generate.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "perf-audit registered" "grep -rq 'perf-audit' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"
test_case "testplan-generate registered" "grep -rq 'testplan-generate' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"

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
