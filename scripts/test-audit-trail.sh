#!/bin/bash
set -o pipefail

echo "Test Suite: v0.69.0 — Audit Trail & Compliance"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PASS=0
FAIL=0

# Test 1: Commands exist
for cmd in audit-trail audit-export audit-search audit-alert; do
  if [ -f ".opencode/commands/${cmd}.md" ]; then
    echo "✅ ${cmd}.md found"
    ((PASS++))
  else
    echo "❌ ${cmd}.md missing"
    ((FAIL++))
  fi
done

# Test 2: Line counts
for cmd in audit-trail audit-export audit-search audit-alert; do
  LINES=$(wc -l < ".opencode/commands/${cmd}.md")
  if [ "$LINES" -le 150 ]; then
    echo "✅ ${cmd}.md: $LINES lines"
    ((PASS++))
  else
    echo "❌ ${cmd}.md: $LINES lines (over 150)"
    ((FAIL++))
  fi
done

# Test 3: Frontmatter
for cmd in audit-trail audit-export audit-search audit-alert; do
  if head -1 ".opencode/commands/${cmd}.md" | grep -q "^---$"; then
    echo "✅ ${cmd}.md frontmatter"
    ((PASS++))
  else
    echo "❌ ${cmd}.md no frontmatter"
    ((FAIL++))
  fi
done

# Test 4: Key concepts
KEYWORDS=("audit" "trail" "compliance" "EU AI Act" "ISO 42001")
for kw in "${KEYWORDS[@]}"; do
  if grep -q "$kw" .opencode/commands/audit-*.md 2>/dev/null; then
    echo "✅ Keyword '$kw' found"
    ((PASS++))
  else
    echo "❌ Keyword '$kw' missing"
    ((FAIL++))
  fi
done

# Test 5: Total count
TOTAL=$(ls -1 .opencode/commands/*.md | wc -l)
echo "📊 Total commands: $TOTAL"
if [ "$TOTAL" -ge 240 ]; then
  echo "✅ Count is $TOTAL (≥240)"
  ((PASS++))
else
  echo "❌ Count is $TOTAL, expected ≥240"
  ((FAIL++))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: ✅ $PASS | ❌ $FAIL"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
