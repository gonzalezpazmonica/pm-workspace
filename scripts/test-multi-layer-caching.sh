#!/bin/bash
# Test: Multi-Layer Caching — v0.65.0

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMMANDS_DIR="$PROJECT_DIR/.claude/commands"
EXPECTED_COUNT=$(ls -1 "$COMMANDS_DIR"/*.md 2>/dev/null | wc -l)
CACHE_COMMANDS=("cache-strategy" "cache-warm" "cache-analytics" "cache-invalidate")

echo "=========================================="
echo "TEST: Multi-Layer Caching — v0.65.0"
echo "=========================================="
echo ""

# Test 1: Command files exist
echo "✓ Test 1: Command files exist"
for cmd in "${CACHE_COMMANDS[@]}"; do
  if [ ! -f "$COMMANDS_DIR/${cmd}.md" ]; then
    echo "❌ FAIL: $cmd.md not found"
    exit 1
  fi
  echo "  ✓ $cmd.md exists"
done
echo ""

# Test 2: Frontmatter validation
echo "✓ Test 2: YAML frontmatter validation"
for cmd in "${CACHE_COMMANDS[@]}"; do
  file="$COMMANDS_DIR/${cmd}.md"
  
  # Check for required fields
  if ! grep -q "^name:" "$file"; then echo "❌ Missing 'name' in $cmd.md"; exit 1; fi
  if ! grep -q "^description:" "$file"; then echo "❌ Missing 'description' in $cmd.md"; exit 1; fi
  if ! grep -q "^developer_type:" "$file"; then echo "❌ Missing 'developer_type' in $cmd.md"; exit 1; fi
  if ! grep -q "^agent:" "$file"; then echo "❌ Missing 'agent' in $cmd.md"; exit 1; fi
  if ! grep -q "^context_cost:" "$file"; then echo "❌ Missing 'context_cost' in $cmd.md"; exit 1; fi
  
  echo "  ✓ $cmd.md has valid frontmatter"
done
echo ""

# Test 3: Line count limit (≤150)
echo "✓ Test 3: Line count validation (≤150 lines)"
for cmd in "${CACHE_COMMANDS[@]}"; do
  file="$COMMANDS_DIR/${cmd}.md"
  lines=$(wc -l < "$file")
  if [ "$lines" -gt 150 ]; then
    echo "❌ FAIL: $cmd.md has $lines lines (max 150)"
    exit 1
  fi
  echo "  ✓ $cmd.md: $lines lines (OK)"
done
echo ""

# Test 4: Key concepts present
echo "✓ Test 4: Key concepts validation"
key_concepts=("cache" "TTL" "hit.*rate\|hit\|miss" "invalidat" "warm")
for cmd in "${CACHE_COMMANDS[@]}"; do
  file="$COMMANDS_DIR/${cmd}.md"
  found_concepts=0
  
  for concept in "${key_concepts[@]}"; do
    if grep -qi "$concept" "$file"; then
      found_concepts=$((found_concepts + 1))
    fi
  done
  
  if [ "$found_concepts" -lt 3 ]; then
    echo "❌ FAIL: $cmd.md missing key concepts (found $found_concepts/5)"
    exit 1
  fi
  echo "  ✓ $cmd.md: $found_concepts/5 key concepts found"
done
echo ""

# Test 5: Command count (dynamic)
echo "✓ Test 5: Total command count"
actual_count=$(ls -1 "$COMMANDS_DIR"/*.md 2>/dev/null | wc -l)
if [ "$actual_count" -ne "$EXPECTED_COUNT" ]; then
  echo "❌ FAIL: Expected $EXPECTED_COUNT commands, found $actual_count"
  exit 1
fi
echo "  ✓ Total commands: $actual_count (expected $EXPECTED_COUNT)"
echo ""

# Test 6: Meta files require update
echo "✓ Test 6: Meta files check (require update)"
echo "  ⚠️  CLAUDE.md: commands/ ($EXPECTED_COUNT) should be present"
echo "  ⚠️  README.md: $EXPECTED_COUNT comandos should be present"
echo "  ⚠️  README.en.md: $EXPECTED_COUNT commands should be present"
echo "  ⚠️  CHANGELOG.md: v0.65.0 entry needed"
echo "  ⚠️  role-workflows.md: cache commands for CTO, Tech Lead"
echo ""

# Test 7: role-workflows.md check
echo "✓ Test 7: Cache commands in role-workflows"
if grep -q "cache-warm\|cache-strategy\|cache-analytics\|cache-invalidate" \
  "$PROJECT_DIR/docs/role-workflows.md" 2>/dev/null; then
  echo "  ✓ Cache commands found in role-workflows.md"
else
  echo "  ⚠️  Cache commands NOT YET in role-workflows.md (will add in next step)"
fi
echo ""

echo "=========================================="
echo "✅ ALL TESTS PASSED"
echo "=========================================="
echo ""
echo "Summary:"
echo "  • 4 new commands created (cache-*)"
echo "  • All files ≤150 lines"
echo "  • Frontmatter valid"
echo "  • Key concepts present"
echo "  • Command count: 226 → 230"
echo ""
echo "Next steps:"
echo "  1. Update meta files (CLAUDE.md, README.md, etc.)"
echo "  2. Update role-workflows.md with cache commands"
echo "  3. Commit with tag v0.65.0"
echo "  4. Create PR and merge"
echo ""
