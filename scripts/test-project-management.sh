#!/bin/bash
# Test: Project Management v0.71.0 (Era 13)
# Validates: 5 project-* commands, frontmatter, ≤150 lines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Project Management v0.71.0 — Era 13"
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
test_case "project-assign.md exists" "[ -f $REPO_ROOT/.claude/commands/project-assign.md ]"
test_case "project-audit.md exists" "[ -f $REPO_ROOT/.claude/commands/project-audit.md ]"
test_case "project-kickoff.md exists" "[ -f $REPO_ROOT/.claude/commands/project-kickoff.md ]"
test_case "project-release-plan.md exists" "[ -f $REPO_ROOT/.claude/commands/project-release-plan.md ]"
test_case "project-roadmap.md exists" "[ -f $REPO_ROOT/.claude/commands/project-roadmap.md ]"

# ── Test 2: YAML frontmatter ────────────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter"
for cmd in project-assign project-audit project-kickoff project-release-plan project-roadmap; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
done

# ── Test 3: Line count ≤ 150 ────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines)"
for cmd in project-assign project-audit project-kickoff project-release-plan project-roadmap; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "project-assign mentions assign\|allocation" "grep -q -i 'assign\|allocation' $REPO_ROOT/.claude/commands/project-assign.md"
test_case "project-audit mentions audit\|review" "grep -q -i 'audit\|review' $REPO_ROOT/.claude/commands/project-audit.md"
test_case "project-kickoff mentions kickoff\|start" "grep -q -i 'kickoff\|start' $REPO_ROOT/.claude/commands/project-kickoff.md"
test_case "project-release-plan mentions release\|plan" "grep -q -i 'release\|plan' $REPO_ROOT/.claude/commands/project-release-plan.md"
test_case "project-roadmap mentions roadmap\|vision" "grep -q -i 'roadmap\|vision' $REPO_ROOT/.claude/commands/project-roadmap.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "project-audit registered" "grep -rq 'project-audit' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"
test_case "project-kickoff registered" "grep -rq 'project-kickoff' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"

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
