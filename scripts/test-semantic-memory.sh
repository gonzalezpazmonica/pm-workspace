#!/bin/bash
# Test suite for Semantic Memory 2.0 v0.64.0

PASSED=0
FAILED=0
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

test() {
  if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASSED++))
  else
    echo -e "  ${RED}✗${NC} $1"
    ((FAILED++))
  fi
}

echo "═══════════════════════════════════════════════════════════════════"
echo "  Test Suite — Semantic Memory 2.0 (v0.64.0)"
echo "═══════════════════════════════════════════════════════════════════"
echo

echo "[Test 1] Command files exist"
for cmd in memory-compress memory-importance memory-graph memory-prune; do
  [ -f "/home/monica/claude/.claude/commands/$cmd.md" ]; test "$cmd.md exists"
done
echo

echo "[Test 2] Line count ≤ 150"
for cmd in memory-compress memory-importance memory-graph memory-prune; do
  lines=$(wc -l < "/home/monica/claude/.claude/commands/$cmd.md" 2>/dev/null)
  [ "$lines" -le 150 ]; test "$cmd.md: $lines lines"
done
echo

echo "[Test 3] YAML frontmatter"
for cmd in memory-compress memory-importance memory-graph memory-prune; do
  path="/home/monica/claude/.claude/commands/$cmd.md"
  grep -q "^---$" "$path" && grep -q "^name:" "$path" && grep -q "^context_cost:" "$path"
  test "$cmd.md: frontmatter"
done
echo

echo "[Test 4] Keywords: compress, importance, graph, prune, engram, semantic"
grep -l "compress\|importance\|graph\|prune\|engram\|semántico\|semantic" /home/monica/claude/.claude/commands/memory-*.md 2>/dev/null | grep -q memory-
test "keywords present"
echo

echo "[Test 5] Meta files updated"
grep -q "commands/ (225)" /home/monica/claude/CLAUDE.md; test "CLAUDE.md: 225"
grep -q "225 comandos" /home/monica/claude/README.md; test "README.md: 225"
grep -q "225 commands" /home/monica/claude/README.en.md; test "README.en.md: 225"
grep -q "0.64.0" /home/monica/claude/CHANGELOG.md; test "CHANGELOG.md: v0.64.0"
grep -q "Semantic Memory" /home/monica/claude/.claude/profiles/context-map.md; test "context-map.md: group"
grep -q "memory-compress\|memory-importance\|memory-graph\|memory-prune" /home/monica/claude/.claude/rules/domain/role-workflows.md; test "role-workflows.md: commands"
echo

echo "[Test 6] Spanish + Savia persona"
grep -q "Savia" /home/monica/claude/.claude/commands/memory-compress.md; test "memory-compress: Savia"
grep -q "Savia" /home/monica/claude/.claude/commands/memory-importance.md; test "memory-importance: Savia"
grep -q "Savia" /home/monica/claude/.claude/commands/memory-graph.md; test "memory-graph: Savia"
grep -q "Savia" /home/monica/claude/.claude/commands/memory-prune.md; test "memory-prune: Savia"
echo

echo "═══════════════════════════════════════════════════════════════════"
echo "  Results: Passed $PASSED | Failed $FAILED"
echo "═══════════════════════════════════════════════════════════════════"
[ "$FAILED" -eq 0 ]
