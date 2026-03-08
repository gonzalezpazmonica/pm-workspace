#!/bin/bash
# Test: Integrations External v0.71.0 (Era 13)
# Validates: 17 integration commands, frontmatter, ≤150 lines

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "═════════════════════════════════════════════════════════════"
echo "  TEST: Integrations External v0.71.0 — Era 13"
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
for cmd in jira-connect jira-sync github-projects github-issues github-activity linear-sync notion-sync confluence-publish gdrive-upload slack-search whatsapp-search nctalk-search sentry-bugs sentry-health figma-extract wiki-sync wiki-publish; do
  test_case "${cmd}.md exists" "[ -f $REPO_ROOT/.claude/commands/${cmd}.md ]"
done

# ── Test 2: YAML frontmatter (sample) ────────────────────────────────
echo ""
echo "2️⃣  YAML Frontmatter (sample)"
for cmd in jira-connect github-projects slack-search sentry-bugs; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  test_case "${cmd}: has name field" "grep -q '^name: ' $file"
  test_case "${cmd}: has description" "grep -q '^description: ' $file"
done

# ── Test 3: Line count ≤ 150 (sample) ────────────────────────────────
echo ""
echo "3️⃣  Line Count (≤ 150 lines) — sample"
for cmd in jira-connect github-projects slack-search; do
  file="$REPO_ROOT/.claude/commands/${cmd}.md"
  lines=$(wc -l < "$file")
  test_case "${cmd}: ${lines} lines ≤ 150" "[ $lines -le 150 ]"
done

# ── Test 4: Key concepts present ────────────────────────────────
echo ""
echo "4️⃣  Key Concepts"
test_case "jira-connect mentions jira" "grep -q -i 'jira' $REPO_ROOT/.claude/commands/jira-connect.md"
test_case "github-projects mentions github" "grep -q -i 'github' $REPO_ROOT/.claude/commands/github-projects.md"
test_case "slack-search mentions slack" "grep -q -i 'slack' $REPO_ROOT/.claude/commands/slack-search.md"
test_case "sentry-bugs mentions sentry" "grep -q -i 'sentry' $REPO_ROOT/.claude/commands/sentry-bugs.md"

# ── Test 5: Meta files updated ──────────────────────────────────
echo ""
echo "5️⃣  Meta Files Updated"
test_case "jira-connect registered" "grep -rq 'jira-connect' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"
test_case "slack-search registered" "grep -rq 'slack-search' $REPO_ROOT/CLAUDE.md $REPO_ROOT/README.md $REPO_ROOT/.claude/profiles/context-map.md 2>/dev/null"

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
