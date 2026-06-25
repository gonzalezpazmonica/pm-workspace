#!/usr/bin/env bash
# monthly-diagnostic-report.sh — SPEC-188 F4 — Monthly diagnostic quality report
set -uo pipefail
#
# Generates a monthly Markdown report aggregating:
#   - diagnostic-metrics-tracker.py stats (accuracy, confidence, rework rate)
#   - failure-pattern-memory.sh stats (pattern counts, open/resolved)
#   - fix-survival-check.sh (survival rate for the month)
#
# Usage:
#   bash scripts/monthly-diagnostic-report.sh [--month YYYY-MM]
#
# Output:
#   output/reports/diagnostic-YYYY-MM.md
#
# Ref: SPEC-188 P4 — Diagnostic Quality Metrics
set -uo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
MONTH=""
OUTPUT_DIR="${REPO_ROOT}/output/reports"

# ── Argument parsing ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --month) MONTH="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

# Default: current month
if [[ -z "$MONTH" ]]; then
  MONTH=$(date -u +"%Y-%m" 2>/dev/null \
    || python3 -c "from datetime import date; print(date.today().strftime('%Y-%m'))")
fi

# Validate format
if ! echo "$MONTH" | grep -qE '^[0-9]{4}-[0-9]{2}$'; then
  echo "ERROR: --month must be YYYY-MM format, got: $MONTH" >&2
  exit 1
fi

YEAR="${MONTH%-*}"
MON="${MONTH#*-}"
GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
  || python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat())")

mkdir -p "$OUTPUT_DIR"
REPORT_FILE="${OUTPUT_DIR}/diagnostic-${MONTH}.md"

# ── Section: Diagnostic Metrics ───────────────────────────────────────────
METRICS_LOG="${REPO_ROOT}/output/diagnostic-metrics.jsonl"
METRICS_SECTION=""
ACCURACY_RATE="N/A"
MEAN_CONFIDENCE="N/A"
REWORK_RATE="N/A"
TOTAL_INV="0"

if [[ -f "$METRICS_LOG" ]]; then
  METRICS_JSON=$(python3 "${REPO_ROOT}/scripts/diagnostic-metrics-tracker.py" \
    --report --log "$METRICS_LOG" 2>/dev/null || echo "{}")
  TOTAL_INV=$(echo "$METRICS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total_investigations',0))" 2>/dev/null || echo "0")
  ACCURACY_RATE=$(echo "$METRICS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('accuracy_rate','N/A'))" 2>/dev/null || echo "N/A")
  MEAN_CONFIDENCE=$(echo "$METRICS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('mean_confidence','N/A'))" 2>/dev/null || echo "N/A")
  REWORK_RATE=$(echo "$METRICS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('rework_rate','N/A'))" 2>/dev/null || echo "N/A")
fi

# ── Section: Failure Patterns ─────────────────────────────────────────────
FPM_SCRIPT="${REPO_ROOT}/scripts/failure-pattern-memory.sh"
PATTERNS_TOTAL="N/A"
PATTERNS_OPEN="N/A"
PATTERNS_RESOLVED="N/A"

if [[ -f "$FPM_SCRIPT" ]]; then
  FPM_STATS=$(bash "$FPM_SCRIPT" stats 2>/dev/null || echo "")
  if [[ -n "$FPM_STATS" ]]; then
    PATTERNS_TOTAL=$(echo "$FPM_STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total', d.get('patterns_total','N/A')))" 2>/dev/null || echo "N/A")
    PATTERNS_OPEN=$(echo "$FPM_STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('open', d.get('patterns_open','N/A')))" 2>/dev/null || echo "N/A")
    PATTERNS_RESOLVED=$(echo "$FPM_STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('resolved', d.get('patterns_resolved','N/A')))" 2>/dev/null || echo "N/A")
  fi
fi

# ── Section: Fix Survival ─────────────────────────────────────────────────
SURVIVAL_RATE="N/A"
FIXES_TOTAL="N/A"
FIXES_SURVIVED="N/A"

SURVIVAL_JSON=$(bash "${REPO_ROOT}/scripts/fix-survival-check.sh" --json --days 30 2>/dev/null || echo "")
if [[ -n "$SURVIVAL_JSON" ]]; then
  SURVIVAL_RATE=$(echo "$SURVIVAL_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('survival_rate','N/A'))" 2>/dev/null || echo "N/A")
  FIXES_TOTAL=$(echo "$SURVIVAL_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('fixes_total','N/A'))" 2>/dev/null || echo "N/A")
  FIXES_SURVIVED=$(echo "$SURVIVAL_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('fixes_survived','N/A'))" 2>/dev/null || echo "N/A")
fi

# ── Write report ──────────────────────────────────────────────────────────
cat > "$REPORT_FILE" <<REPORT_EOF
---
report_type: diagnostic-quality
month: ${MONTH}
generated_at: ${GENERATED_AT}
spec_ref: SPEC-188
---

# Diagnostic Quality Report — ${MONTH}

> Generated: ${GENERATED_AT}
> Ref: SPEC-188 P4 — Root-Cause Investigation Architecture

## Summary

| Metric | Value |
|---|---|
| Investigations tracked | ${TOTAL_INV} |
| Accuracy rate | ${ACCURACY_RATE} |
| Mean confidence | ${MEAN_CONFIDENCE} |
| Rework rate | ${REWORK_RATE} |
| Fix survival rate (30 days) | ${SURVIVAL_RATE} |
| Fixes total | ${FIXES_TOTAL} |
| Fixes survived | ${FIXES_SURVIVED} |

## Failure Patterns

| Metric | Value |
|---|---|
| Patterns total | ${PATTERNS_TOTAL} |
| Patterns open | ${PATTERNS_OPEN} |
| Patterns resolved | ${PATTERNS_RESOLVED} |

## Fix Survival

Fixes checked over last 30 days:
- Total fix commits: ${FIXES_TOTAL}
- Survived (not reverted): ${FIXES_SURVIVED}
- Survival rate: ${SURVIVAL_RATE}

$(if [[ "$SURVIVAL_RATE" != "N/A" ]] && python3 -c "import sys; r=float('${SURVIVAL_RATE}'); sys.exit(0 if r < 0.7 else 1)" 2>/dev/null; then
  echo "> **Warning**: survival rate below 0.70 — review recent fix quality with the human reviewer."
fi)

## Diagnostic Investigations

- Total investigations recorded: ${TOTAL_INV}
- Accuracy rate (was_correct): ${ACCURACY_RATE}
- Mean causal confidence: ${MEAN_CONFIDENCE}
- Rework rate: ${REWORK_RATE}

$(if [[ "$REWORK_RATE" != "N/A" ]] && python3 -c "import sys; r=float('${REWORK_RATE}'); sys.exit(0 if r > 0.25 else 1)" 2>/dev/null; then
  echo "> **Warning**: rework rate above 0.25 — indicates symptom patching rather than root-cause fixing."
fi)

## Data Sources

- diagnostic-metrics-tracker: \`output/diagnostic-metrics.jsonl\`
- failure-pattern-memory: \`scripts/failure-pattern-memory.sh stats\`
- fix-survival: \`scripts/fix-survival-check.sh --json --days 30\`

---

*Report generated by scripts/monthly-diagnostic-report.sh (SPEC-188 F4)*
REPORT_EOF

echo "Report written: $REPORT_FILE"
