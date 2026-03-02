#!/bin/bash
# Test: Pipeline & DevOps v0.71.0 (Era 13)
# Validates: 6 pipeline/devops commands, frontmatter, ≤150 lines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Pipeline & DevOps v0.71.0 — Era 13"
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
test_case "pipeline-create.md exists" "[ -f $REPO_ROOT/.claude/commands/pipeline-create.md ]"
test_case "pipeline-run.md exists" "[ -f $REPO_ROOT/.claude/commands/pipeline-run.md ]"
test_case "pipeline-status.md exists" "[ -f $REPO_ROOT/.claude/commands/pipeline-status.md ]"
test_case "pipeline-logs.md exists" "[ -f $REPO_ROOT/.claude/commands/pipeline-logs.md ]"
test_case "pipeline-artifacts.md exists" "[ -f $REPO_ROOT/.claude/commands/pipeline-artifacts.md ]"
test_case "devops-validate.md exists" "[ -f $REPO_ROOT/.claude/commands/devops-validate.md ]"

# ── Test 2: YAML frontmatter ────────────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter"
for cmd in pipeline-create pipeline-run pipeline-status devops-validate; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
done

# ── Test 3: Line count ≤ 150 ────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines)"
for cmd in pipeline-create pipeline-run pipeline-status devops-validate; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "pipeline-create mentions pipeline\|create" "grep -q -i 'pipeline\|create' $REPO_ROOT/.claude/commands/pipeline-create.md"
test_case "pipeline-run mentions run\|execute" "grep -q -i 'run\|execute' $REPO_ROOT/.claude/commands/pipeline-run.md"
test_case "pipeline-status mentions status" "grep -q -i 'status' $REPO_ROOT/.claude/commands/pipeline-status.md"
test_case "devops-validate mentions devops\|validate" "grep -q -i 'devops\|validate' $REPO_ROOT/.claude/commands/devops-validate.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "pipeline-create registered" "grep -rq 'pipeline-create' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"
test_case "pipeline registered" "grep -rq -i 'pipeline' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"

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
