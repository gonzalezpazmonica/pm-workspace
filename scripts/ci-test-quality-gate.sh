#!/usr/bin/env bash
# ci-test-quality-gate.sh — CI gate: test quality + coverage
# SPEC-055: Blocks CI if any test scores < 80
# Usage: bash scripts/ci-test-quality-gate.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=true

echo "=== CI Test Quality Gate (SPEC-055) ==="
echo ""

# Step 1: Audit test quality
echo "Step 1/2: Auditing test quality..."
AUDIT=$(bash "$DIR/test-auditor.sh" --all --json 2>&1) || true
FAILED=$(echo "$AUDIT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('failed',0))" 2>/dev/null || echo "0")
TOTAL=$(echo "$AUDIT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total_files',0))" 2>/dev/null || echo "0")
echo "  Audited: $TOTAL files, $FAILED below threshold"
if [[ "$FAILED" -gt 0 ]]; then
  echo "$AUDIT" | python3 -c "
import json,sys
for r in json.load(sys.stdin).get('results',[]):
    if r.get('total',0)<80: print(f'    {r[\"file\"]}: {r[\"total\"]}/100')
" 2>/dev/null
  PASS=false
fi

# Step 2: Coverage
echo "Step 2/2: Checking coverage..."
COV=$(bash "$DIR/test-coverage-checker.sh" --json 2>&1)
echo "  $(echo "$COV" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'Coverage: {d[\"coverage_percent\"]}%')" 2>/dev/null)"

echo ""
if $PASS; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL — tests below quality threshold"
  exit 1
fi
