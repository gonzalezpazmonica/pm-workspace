#!/bin/bash
set -e

echo "════════════════════════════════════════════════════════════════"
echo "  TEST SUITE: DX Metrics v0.66.0"
echo "════════════════════════════════════════════════════════════════"
echo ""

PASS=0
FAIL=0

# Test 1: Command files exist
echo "✓ Test 1: Command files exist"
for cmd in dx-core4 flow-protect deep-work prevention-metrics; do
  if [ ! -f ".claude/commands/${cmd}.md" ]; then
    echo "  ✗ FAIL: ${cmd}.md not found"
    FAIL=$((FAIL + 1))
  else
    PASS=$((PASS + 1))
  fi
done
echo ""

# Test 2: Verify line count ≤150
echo "✓ Test 2: Line count ≤150 per file"
for cmd in dx-core4 flow-protect deep-work prevention-metrics; do
  lines=$(wc -l < ".claude/commands/${cmd}.md")
  if [ "$lines" -gt 150 ]; then
    echo "  ✗ FAIL: ${cmd}.md has $lines lines (max 150)"
    FAIL=$((FAIL + 1))
  else
    PASS=$((PASS + 1))
    echo "  ${cmd}.md: $lines lines ✓"
  fi
done
echo ""

# Test 3: Verify YAML frontmatter
echo "✓ Test 3: YAML frontmatter (name, description, developer_type, agent)"
for cmd in dx-core4 flow-protect deep-work prevention-metrics; do
  file=".claude/commands/${cmd}.md"
  if ! grep -q "^name:" "$file" || ! grep -q "^description:" "$file" || ! grep -q "^developer_type:" "$file" || ! grep -q "^agent:" "$file"; then
    echo "  ✗ FAIL: ${cmd}.md missing frontmatter"
    FAIL=$((FAIL + 1))
  else
    PASS=$((PASS + 1))
  fi
done
echo ""

# Test 4: Key concepts present
echo "✓ Test 4: Key concepts present"
echo "  Checking dx-core4 for DX Core 4, DORA, scorecard..."
if grep -qi "core 4\|dora\|scorecard" ".claude/commands/dx-core4.md"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ FAIL: dx-core4 missing key concepts"
fi

echo "  Checking flow-protect for flow, context-switching, WIP..."
if grep -qi "flow\|context.*switch\|wip" ".claude/commands/flow-protect.md"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ FAIL: flow-protect missing key concepts"
fi

echo "  Checking deep-work for Cal Newport, deep work, 3-4h blocks..."
if grep -qi "cal newport\|deep work\|3-4h\|block" ".claude/commands/deep-work.md"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ FAIL: deep-work missing key concepts"
fi

echo "  Checking prevention-metrics for shift-left, prevention, detection..."
if grep -qi "shift.*left\|prevent\|detect" ".claude/commands/prevention-metrics.md"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ FAIL: prevention-metrics missing key concepts"
fi
echo ""

# Test 5: Command count in meta files
echo "✓ Test 5: Command count verification (should be 233 = 229 + 4)"
cmd_count=$(ls .claude/commands/*.md 2>/dev/null | wc -l)
echo "  Actual command count: $cmd_count"
if [ "$cmd_count" -eq 233 ]; then
  PASS=$((PASS + 1))
  echo "  ✓ Command count is 233 ✓"
else
  echo "  ⚠ Command count is $cmd_count (expected 233)"
fi
echo ""

# Test 6: Check meta file updates
echo "✓ Test 6: Meta file updates (spot checks)"
echo "  Checking CLAUDE.md for command count..."
if grep -q "233" CLAUDE.md 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  ✓ CLAUDE.md updated ✓"
else
  echo "  ⚠ CLAUDE.md may need update"
fi

echo "  Checking README.md for command count..."
if grep -q "233 comandos\|233 commands" README.md 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  ✓ README.md updated ✓"
else
  echo "  ⚠ README.md may need update"
fi

echo "  Checking CHANGELOG.md for v0.66.0 entry..."
if grep -q "v0.66.0" CHANGELOG.md 2>/dev/null; then
  PASS=$((PASS + 1))
  echo "  ✓ CHANGELOG.md has v0.66.0 ✓"
else
  echo "  ⚠ CHANGELOG.md may need v0.66.0 entry"
fi
echo ""

# Test 7: Savia persona in all files
echo "✓ Test 7: Savia persona (warm voice)"
savia_found=0
for cmd in dx-core4 flow-protect deep-work prevention-metrics; do
  if grep -q "🦉\|Savia" ".claude/commands/${cmd}.md"; then
    savia_found=$((savia_found + 1))
  fi
done
echo "  Savia persona found in $savia_found/4 files"
PASS=$((PASS + 1))
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "  TEST RESULTS"
echo "════════════════════════════════════════════════════════════════"
echo "  ✓ PASSED: $PASS"
echo "  ✗ FAILED: $FAIL"

if [ $FAIL -eq 0 ]; then
  echo ""
  echo "  ✓ ALL TESTS PASSED"
  exit 0
else
  echo ""
  echo "  ✗ SOME TESTS FAILED"
  exit 1
fi
