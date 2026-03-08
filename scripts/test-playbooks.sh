#!/bin/bash
# Test: Playbooks v0.71.0 (Era 13)
# Validates: 4 playbook-* commands, frontmatter, ≤150 lines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Playbooks v0.71.0 — Era 13"
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
test_case "playbook-create.md exists" "[ -f $REPO_ROOT/.claude/commands/playbook-create.md ]"
test_case "playbook-evolve.md exists" "[ -f $REPO_ROOT/.claude/commands/playbook-evolve.md ]"
test_case "playbook-library.md exists" "[ -f $REPO_ROOT/.claude/commands/playbook-library.md ]"
test_case "playbook-reflect.md exists" "[ -f $REPO_ROOT/.claude/commands/playbook-reflect.md ]"

# ── Test 2: YAML frontmatter ────────────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter"
for cmd in playbook-create playbook-evolve playbook-library playbook-reflect; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
done

# ── Test 3: Line count ≤ 150 ────────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines)"
for cmd in playbook-create playbook-evolve playbook-library playbook-reflect; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "playbook-create mentions create\|define" "grep -q -i 'create\|define' $REPO_ROOT/.claude/commands/playbook-create.md"
test_case "playbook-evolve mentions evolve\|improve" "grep -q -i 'evolve\|improve' $REPO_ROOT/.claude/commands/playbook-evolve.md"
test_case "playbook-library mentions library\|reuse" "grep -q -i 'library\|reuse' $REPO_ROOT/.claude/commands/playbook-library.md"
test_case "playbook-reflect mentions reflect\|learn" "grep -q -i 'reflect\|learn' $REPO_ROOT/.claude/commands/playbook-reflect.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "playbook-create registered" "grep -rq 'playbook-create' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"
test_case "playbook registered" "grep -rq -i 'playbook' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"

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
