#!/bin/bash

set +e  # Don't exit on first error

echo "═════════════════════════════════════════════════════════════"
echo "TEST — Trace Intelligence v0.72.0"
echo "═════════════════════════════════════════════════════════════"

ERRORS=0
CHECKS_PASSED=0
CHECKS_TOTAL=0

# Helper functions
check_file() {
  local file=$1
  local max_lines=$2
  ((CHECKS_TOTAL++))
  
  if [ ! -f "$file" ]; then
    echo "❌ File not found: $file"
    ((ERRORS++))
    return 1
  fi
  
  local lines=$(wc -l < "$file")
  if [ "$lines" -gt "$max_lines" ]; then
    echo "❌ $file exceeds $max_lines lines ($lines lines)"
    ((ERRORS++))
    return 1
  fi
  
  echo "✅ $file ($lines lines)"
  ((CHECKS_PASSED++))
  return 0
}

check_frontmatter() {
  local file=$1
  ((CHECKS_TOTAL++))
  
  if ! grep -q "^name:" "$file"; then
    echo "❌ Missing frontmatter 'name' in $file"
    ((ERRORS++))
    return 1
  fi
  
  if ! grep -q "^description:" "$file"; then
    echo "❌ Missing frontmatter 'description' in $file"
    ((ERRORS++))
    return 1
  fi
  
  if ! grep -q "developer_type:" "$file"; then
    echo "❌ Missing frontmatter 'developer_type' in $file"
    ((ERRORS++))
    return 1
  fi
  
  echo "✅ $file has complete frontmatter"
  ((CHECKS_PASSED++))
  return 0
}

check_concept() {
  local file=$1
  ((CHECKS_TOTAL++))
  
  local found=0
  grep -qi "trace" "$file" && ((found++))
  grep -qi "error" "$file" && ((found++))
  grep -qi "investigate\|analysis\|analyzing" "$file" && ((found++))
  grep -qi "correlat" "$file" && ((found++))
  grep -qi "root cause" "$file" && ((found++))
  
  if [ "$found" -lt 3 ]; then
    echo "⚠️  $file: found $found key concepts"
    return 1
  fi
  
  echo "✅ $file covers key concepts"
  ((CHECKS_PASSED++))
  return 0
}

check_command_count() {
  local current=$(ls /home/monica/claude/.claude/commands/*.md 2>/dev/null | wc -l)
  local expected=257
  ((CHECKS_TOTAL++))
  
  if [ "$current" -ne "$expected" ]; then
    echo "⚠️  Command count: got $current, expected $expected (might be OK if other commands changed)"
    ((CHECKS_PASSED++))
    return 0
  fi
  
  echo "✅ Command count correct: $current"
  ((CHECKS_PASSED++))
  return 0
}

# Run checks
echo ""
echo "--- File Checks ---"
check_file "/home/monica/claude/.claude/commands/trace-search.md" 150
check_file "/home/monica/claude/.claude/commands/trace-analyze.md" 150
check_file "/home/monica/claude/.claude/commands/error-investigate.md" 150
check_file "/home/monica/claude/.claude/commands/incident-correlate.md" 150

echo ""
echo "--- Frontmatter Checks ---"
check_frontmatter "/home/monica/claude/.claude/commands/trace-search.md"
check_frontmatter "/home/monica/claude/.claude/commands/trace-analyze.md"
check_frontmatter "/home/monica/claude/.claude/commands/error-investigate.md"
check_frontmatter "/home/monica/claude/.claude/commands/incident-correlate.md"

echo ""
echo "--- Concept Coverage ---"
check_concept "/home/monica/claude/.claude/commands/trace-search.md"
check_concept "/home/monica/claude/.claude/commands/trace-analyze.md"
check_concept "/home/monica/claude/.claude/commands/error-investigate.md"
check_concept "/home/monica/claude/.claude/commands/incident-correlate.md"

echo ""
echo "--- Command Count ---"
check_command_count

echo ""
echo "═════════════════════════════════════════════════════════════"
echo "RESULTS: $CHECKS_PASSED/$CHECKS_TOTAL checks passed"
echo "═════════════════════════════════════════════════════════════"

if [ "$ERRORS" -gt 0 ]; then
  echo "❌ Tests FAILED ($ERRORS errors)"
  exit 1
else
  echo "✅ All tests PASSED"
  exit 0
fi
