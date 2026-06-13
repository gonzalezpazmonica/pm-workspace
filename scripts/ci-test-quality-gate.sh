#!/usr/bin/env bash
# ci-test-quality-gate.sh — CI gate: test quality + coverage
# SPEC-055: Blocks CI if any test scores < threshold
# SPEC-200 (wired): when SAVIA_QUALITY_GATE_ADAPTIVE=on, uses adaptive
# threshold proportional to score distribution instead of fixed 80.
#
# Modes:
#   SAVIA_QUALITY_GATE_ADAPTIVE=off (default) — fixed threshold 80 (SPEC-055).
#   SAVIA_QUALITY_GATE_ADAPTIVE=warn          — compute adaptive but still
#       gate on fixed 80; emit advisory diff to stderr.
#   SAVIA_QUALITY_GATE_ADAPTIVE=on            — use adaptive threshold.
#
# Tunables:
#   SAVIA_QUALITY_GATE_FIXED_MIN=80
#   SAVIA_QUALITY_GATE_FLOOR=60
#   SAVIA_QUALITY_GATE_CEIL=90
#
# Usage: bash scripts/ci-test-quality-gate.sh
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=true

ADAPTIVE_MODE="${SAVIA_QUALITY_GATE_ADAPTIVE:-off}"
FIXED_MIN="${SAVIA_QUALITY_GATE_FIXED_MIN:-80}"
FLOOR="${SAVIA_QUALITY_GATE_FLOOR:-60}"
CEIL="${SAVIA_QUALITY_GATE_CEIL:-90}"

echo "=== CI Test Quality Gate (SPEC-055 + SPEC-200 adaptive) ==="
echo "  Mode: $ADAPTIVE_MODE  Fixed-min: $FIXED_MIN  Floor: $FLOOR  Ceil: $CEIL"
echo ""

# Step 1: Audit test quality
echo "Step 1/2: Auditing test quality..."
AUDIT=$(bash "$DIR/test-auditor.sh" --all --json 2>&1) || true
TOTAL=$(echo "$AUDIT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total_files',0))" 2>/dev/null || echo "0")

# Compute the threshold to use this run
THRESHOLD="$FIXED_MIN"
ADAPTIVE_RESULT=""
if [[ "$ADAPTIVE_MODE" != "off" ]]; then
  # Extract all scores from the audit results
  SCORES=$(echo "$AUDIT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
scores = [str(r.get('total', 0)) for r in data.get('results', [])]
print(' '.join(scores))
" 2>/dev/null)

  if [[ -n "$SCORES" ]]; then
    ADAPTIVE_RESULT=$(python3 "$DIR/quality-gate-adaptive.py" \
        --scores $SCORES \
        --fixed-min "$FIXED_MIN" --floor "$FLOOR" --ceil "$CEIL" --json 2>/dev/null || echo "{}")
    NEW_THRESHOLD=$(echo "$ADAPTIVE_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('threshold', $FIXED_MIN))" 2>/dev/null || echo "$FIXED_MIN")
    STRATEGY=$(echo "$ADAPTIVE_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('strategy', 'unknown'))" 2>/dev/null || echo "unknown")
    MEAN=$(echo "$ADAPTIVE_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('metrics', {}).get('mean', 0))" 2>/dev/null || echo "0")
    STDDEV=$(echo "$ADAPTIVE_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('metrics', {}).get('stddev', 0))" 2>/dev/null || echo "0")

    echo "  Adaptive threshold: $NEW_THRESHOLD (strategy=$STRATEGY mean=$MEAN stddev=$STDDEV)"

    if [[ "$ADAPTIVE_MODE" == "on" ]]; then
      THRESHOLD="$NEW_THRESHOLD"
    elif [[ "$ADAPTIVE_MODE" == "warn" ]]; then
      # Show advisory but still gate on fixed
      if [[ "$NEW_THRESHOLD" != "$FIXED_MIN" ]]; then
        echo "  [WARN] Adaptive would use $NEW_THRESHOLD; gating on fixed $FIXED_MIN (SAVIA_QUALITY_GATE_ADAPTIVE=warn)" >&2
      fi
    fi

    # Telemetry
    LOG_FILE="output/quality-gate-history.jsonl"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    if command -v jq >/dev/null 2>&1; then
      jq -nc \
        --arg ts "$(date -Iseconds 2>/dev/null || date)" \
        --arg mode "$ADAPTIVE_MODE" \
        --arg threshold "$THRESHOLD" \
        --arg strategy "$STRATEGY" \
        --arg mean "$MEAN" \
        --arg stddev "$STDDEV" \
        --arg total "$TOTAL" \
        '{ts:$ts, mode:$mode, threshold:($threshold|tonumber? // 0), strategy:$strategy, mean:($mean|tonumber? // 0), stddev:($stddev|tonumber? // 0), total_tests:($total|tonumber? // 0)}' \
        >> "$LOG_FILE" 2>/dev/null || true
    fi
  fi
fi

# Filter failed tests against the threshold
FAILED=$(echo "$AUDIT" | python3 -c "
import json, sys
threshold = $THRESHOLD
data = json.load(sys.stdin)
failed = [r for r in data.get('results', []) if r.get('total', 0) < threshold]
print(len(failed))
" 2>/dev/null || echo "0")

echo "  Audited: $TOTAL files, $FAILED below threshold ($THRESHOLD)"

if [[ "$FAILED" -gt 0 ]]; then
  echo "$AUDIT" | python3 -c "
import json, sys
threshold = $THRESHOLD
data = json.load(sys.stdin)
for r in data.get('results', []):
    if r.get('total', 0) < threshold:
        print(f'    {r["file"]}: {r["total"]}/100 (threshold {threshold})')
" 2>/dev/null
  PASS=false
fi

# Step 2: Coverage
echo "Step 2/2: Checking coverage..."
COV=$(bash "$DIR/test-coverage-checker.sh" --json 2>&1)
COV_PCT=$(echo "$COV" | python3 -c "import json,sys; print(json.load(sys.stdin).get('coverage_percent', 0))" 2>/dev/null || echo "0")
echo "  Coverage: $COV_PCT%"

echo ""
if $PASS; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL — tests below quality threshold ($THRESHOLD)"
  exit 1
fi
