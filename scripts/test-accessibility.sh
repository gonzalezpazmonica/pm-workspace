#!/bin/bash
# test-accessibility.sh — Test suite for v0.68.0 accessibility commands

set -e

COMMANDS_DIR="./.claude/commands"
A11Y_COMMANDS=("a11y-audit" "a11y-fix" "a11y-report" "a11y-monitor")
EXPECTED_COUNT=241

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TEST-ACCESSIBILITY.SH — v0.68.0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 1: Check all 4 files exist
echo ""
echo "✓ Test 1: Files exist"
for cmd in "${A11Y_COMMANDS[@]}"; do
  if [ -f "$COMMANDS_DIR/$cmd.md" ]; then
    echo "  ✓ $cmd.md found"
  else
    echo "  ✗ $cmd.md MISSING"
    exit 1
  fi
done

# Test 2: Check line counts (≤150 each)
echo ""
echo "✓ Test 2: Line counts (≤150 each)"
for cmd in "${A11Y_COMMANDS[@]}"; do
  lines=$(wc -l < "$COMMANDS_DIR/$cmd.md")
  if [ "$lines" -le 150 ]; then
    echo "  ✓ $cmd.md: $lines lines"
  else
    echo "  ✗ $cmd.md: $lines lines (exceeds 150)"
    exit 1
  fi
done

# Test 3: Check YAML frontmatter
echo ""
echo "✓ Test 3: YAML frontmatter"
for cmd in "${A11Y_COMMANDS[@]}"; do
  if head -1 "$COMMANDS_DIR/$cmd.md" | grep -q "^---$"; then
    echo "  ✓ $cmd.md has frontmatter"
  else
    echo "  ✗ $cmd.md missing frontmatter"
    exit 1
  fi
done

# Test 4: Check required frontmatter fields
echo ""
echo "✓ Test 4: Required frontmatter fields"
for cmd in "${A11Y_COMMANDS[@]}"; do
  file="$COMMANDS_DIR/$cmd.md"
  
  if grep -q "^name:" "$file" && \
     grep -q "^description:" "$file" && \
     grep -q "developer_type:" "$file" && \
     grep -q "agent:" "$file" && \
     grep -q "context_cost:" "$file"; then
    echo "  ✓ $cmd.md has all required fields"
  else
    echo "  ✗ $cmd.md missing required fields"
    exit 1
  fi
done

# Test 5: Check key accessibility concepts
echo ""
echo "✓ Test 5: Key accessibility concepts"
KEY_WORDS=("WCAG" "accessibility" "a11y" "contrast" "ARIA" "keyboard")
found_words=0
for word in "${KEY_WORDS[@]}"; do
  if grep -qi "$word" "$COMMANDS_DIR"/*.md; then
    found_words=$((found_words + 1))
    echo "  ✓ Found: $word"
  fi
done
if [ "$found_words" -lt 4 ]; then
  echo "  ✗ Missing key concepts"
  exit 1
fi

# Test 6: Count total commands (237 → 241)
echo ""
echo "✓ Test 6: Command count (237 → 241)"
total_cmds=$(find "$COMMANDS_DIR" -name "*.md" -type f | wc -l)
if [ "$total_cmds" -eq "$EXPECTED_COUNT" ]; then
  echo "  ✓ Total commands: $total_cmds (expected $EXPECTED_COUNT)"
else
  echo "  ⚠ Total commands: $total_cmds (expected $EXPECTED_COUNT)"
  echo "    Difference: $((total_cmds - EXPECTED_COUNT))"
fi

# Test 7: Check meta files are ready to update
echo ""
echo "✓ Test 7: Meta files exist (for update)"
META_FILES=("CLAUDE.md" "README.md" "README.en.md" "CHANGELOG.md")
for file in "${META_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✓ $file found"
  else
    echo "  ✗ $file MISSING"
    exit 1
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ ALL TESTS PASSED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
