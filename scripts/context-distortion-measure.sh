#!/usr/bin/env bash
# context-distortion-measure.sh — SE-029-M
# Measures D (distortion) between original and compacted context.
# Heuristic baseline: token-set recall + keyword preservation.
# Production: replace with LLM-judge via ANTHROPIC_API_KEY.
#
# Ref: docs/propuestas/SE-029-rate-distortion-context.md
#      bytebell rate-distortion paper (2026)
#
# Usage:
#   bash scripts/context-distortion-measure.sh \
#     --original FILE --compacted FILE [--task-anchors TERMS] [--json]
#
# Exit codes:
#   0 = distortion measured successfully
#   2 = input error

set -uo pipefail

ORIGINAL=""
COMPACTED=""
TASK_ANCHORS=""
JSON_OUT=false

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --original) ORIGINAL="$2"; shift 2 ;;
    --compacted) COMPACTED="$2"; shift 2 ;;
    --task-anchors) TASK_ANCHORS="$2"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag $1" >&2; exit 2 ;;
  esac
done

[[ -z "$ORIGINAL" ]] && { echo "Error: --original required" >&2; exit 2; }
[[ -z "$COMPACTED" ]] && { echo "Error: --compacted required" >&2; exit 2; }
[[ ! -f "$ORIGINAL" ]] && { echo "Error: file not found: $ORIGINAL" >&2; exit 2; }
[[ ! -f "$COMPACTED" ]] && { echo "Error: file not found: $COMPACTED" >&2; exit 2; }

# ── Token-set recall (baseline metric) ───────────────────────────────────────
# Normalize: lowercase, keep only alphanumeric tokens of length >= 3

extract_tokens() {
  tr '[:upper:]' '[:lower:]' < "$1" \
    | tr -c '[:alnum:]' ' ' \
    | tr -s ' ' '\n' \
    | awk 'length >= 3' \
    | sort -u
}

TMP_ORIG=$(mktemp)
TMP_COMP=$(mktemp)
trap 'rm -f "$TMP_ORIG" "$TMP_COMP" "$TMP_INTER"' EXIT

extract_tokens "$ORIGINAL" > "$TMP_ORIG"
extract_tokens "$COMPACTED" > "$TMP_COMP"
TMP_INTER=$(mktemp)
comm -12 "$TMP_ORIG" "$TMP_COMP" > "$TMP_INTER"

ORIG_COUNT=$(wc -l < "$TMP_ORIG")
COMP_COUNT=$(wc -l < "$TMP_COMP")
INTER_COUNT=$(wc -l < "$TMP_INTER")

# Token-set recall: how much of original tokens survive in compacted
if (( ORIG_COUNT > 0 )); then
  RECALL=$(awk -v i="$INTER_COUNT" -v o="$ORIG_COUNT" 'BEGIN{printf "%.4f", i/o}')
else
  RECALL="0.0000"
fi

# ── Size ratio ───────────────────────────────────────────────────────────────
ORIG_BYTES=$(wc -c < "$ORIGINAL")
COMP_BYTES=$(wc -c < "$COMPACTED")
if (( COMP_BYTES > 0 )); then
  RATIO=$(awk -v o="$ORIG_BYTES" -v c="$COMP_BYTES" 'BEGIN{printf "%.2f", o/c}')
else
  RATIO="0.00"
fi

# ── Task anchor coverage ─────────────────────────────────────────────────────
ANCHOR_HITS=0
ANCHOR_TOTAL=0
if [[ -n "$TASK_ANCHORS" ]]; then
  IFS=',' read -ra ANCHORS <<< "$TASK_ANCHORS"
  ANCHOR_TOTAL=${#ANCHORS[@]}
  for a in "${ANCHORS[@]}"; do
    if grep -qiF "$a" "$COMPACTED"; then
      ANCHOR_HITS=$((ANCHOR_HITS + 1))
    fi
  done
fi

if (( ANCHOR_TOTAL > 0 )); then
  ANCHOR_COV=$(awk -v h="$ANCHOR_HITS" -v t="$ANCHOR_TOTAL" 'BEGIN{printf "%.4f", h/t}')
else
  ANCHOR_COV="1.0000"
fi

# ── Distortion = 1 - weighted(recall, anchor_cov) ────────────────────────────
# weight: 0.4 recall + 0.6 anchor_cov (task-aware per paper)
DISTORTION=$(awk -v r="$RECALL" -v a="$ANCHOR_COV" 'BEGIN{printf "%.4f", 1 - (0.4*r + 0.6*a)}')

# ── Verdict ──────────────────────────────────────────────────────────────────
VERDICT="UNACCEPTABLE"
D_NUM=$(awk -v d="$DISTORTION" 'BEGIN{print d}')
if awk -v d="$D_NUM" 'BEGIN{exit !(d <= 0.15)}'; then
  VERDICT="HIGH_QUALITY"
elif awk -v d="$D_NUM" 'BEGIN{exit !(d <= 0.30)}'; then
  VERDICT="ACCEPTABLE"
fi

# ── Output ───────────────────────────────────────────────────────────────────
if $JSON_OUT; then
  printf '{"ratio":%s,"distortion":%s,"token_recall":%s,"anchor_coverage":%s,"verdict":"%s","original_bytes":%d,"compacted_bytes":%d}\n' \
    "$RATIO" "$DISTORTION" "$RECALL" "$ANCHOR_COV" "$VERDICT" "$ORIG_BYTES" "$COMP_BYTES"
else
  echo "=== Context Distortion Measurement ==="
  echo "  Compression ratio:   ${RATIO}:1"
  echo "  Token-set recall:    ${RECALL}"
  echo "  Anchor coverage:     ${ANCHOR_COV} (${ANCHOR_HITS}/${ANCHOR_TOTAL})"
  echo "  Distortion (D):      ${DISTORTION}"
  echo "  Verdict:             ${VERDICT}"
  echo ""
  echo "  Thresholds (SE-029):"
  echo "    D ≤ 0.15  → HIGH_QUALITY (critical tasks)"
  echo "    D ≤ 0.30  → ACCEPTABLE"
  echo "    D >  0.30 → UNACCEPTABLE (re-compact)"
fi

exit 0
