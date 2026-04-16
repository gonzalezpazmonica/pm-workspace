#!/bin/bash
# Test suite for Semantic Memory 2.0 v0.64.0

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
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
  [ -f "$PROJECT_DIR/.claude/commands/$cmd.md" ]; test "$cmd.md exists"
done
echo

echo "[Test 2] Line count ≤ 150"
for cmd in memory-compress memory-importance memory-graph memory-prune; do
  lines=$(wc -l < "$PROJECT_DIR/.claude/commands/$cmd.md" 2>/dev/null)
  [ "$lines" -le 150 ]; test "$cmd.md: $lines lines"
done
echo

echo "[Test 3] YAML frontmatter"
for cmd in memory-compress memory-importance memory-graph memory-prune; do
  path="$PROJECT_DIR/.claude/commands/$cmd.md"
  grep -q "^---$" "$path" && grep -q "^name:" "$path" && grep -q "^context_cost:" "$path"
  test "$cmd.md: frontmatter"
done
echo

echo "[Test 4] Keywords: compress, importance, graph, prune, engram, semantic"
grep -l "compress\|importance\|graph\|prune\|engram\|semántico\|semantic" $PROJECT_DIR/.claude/commands/memory-*.md 2>/dev/null | grep -q memory-
test "keywords present"
echo

echo "[Test 5] Meta files updated"
EXPECTED_COUNT=$(ls -1 $PROJECT_DIR/.claude/commands/*.md 2>/dev/null | wc -l)
grep -q "commands/ ($EXPECTED_COUNT)" $PROJECT_DIR/CLAUDE.md; test "CLAUDE.md: $EXPECTED_COUNT"
grep -q "memory\|Memory" $PROJECT_DIR/README.md; test "README.md: memory mentions"
grep -q "memory\|Memory" $PROJECT_DIR/README.en.md; test "README.en.md: memory mentions"
grep -q "0.64.0" $PROJECT_DIR/CHANGELOG.md; test "CHANGELOG.md: v0.64.0"
grep -q "memory-compress" $PROJECT_DIR/.claude/profiles/context-map.md || grep -q "memory" $PROJECT_DIR/docs/rules/domain/role-workflows.md; test "context-map or role-workflows: memory"
grep -q "memory-compress\|memory-importance\|memory-graph\|memory-prune" $PROJECT_DIR/docs/rules/domain/role-workflows.md; test "role-workflows.md: commands"
echo

echo "[Test 6] Spanish + Savia persona"
grep -q "Savia" $PROJECT_DIR/.claude/commands/memory-compress.md; test "memory-compress: Savia"
grep -q "Savia" $PROJECT_DIR/.claude/commands/memory-importance.md; test "memory-importance: Savia"
grep -q "Savia" $PROJECT_DIR/.claude/commands/memory-graph.md; test "memory-graph: Savia"
grep -q "Savia" $PROJECT_DIR/.claude/commands/memory-prune.md; test "memory-prune: Savia"
echo

echo "═══════════════════════════════════════════════════════════════════"
echo "  Results: Passed $PASSED | Failed $FAILED"
echo "═══════════════════════════════════════════════════════════════════"
[ "$FAILED" -eq 0 ]
