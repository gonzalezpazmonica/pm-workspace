#!/usr/bin/env bash
# context-restate-anchor.sh — SE-029-R
# Emits a re-state anchor after large compactions (ratio > 20:1) so the
# user can correct context drift immediately.
# Ref: docs/propuestas/SE-029-rate-distortion-context.md
#
# Usage:
#   bash scripts/context-restate-anchor.sh \
#     --ratio N --current-task TEXT --active-spec SPEC-NNN \
#     --last-decision TEXT --next-step TEXT [--degraded TEXT] [--json]
#
# Thresholds:
#   ratio <= 20  → skip (no anchor needed, exit 0 silently)
#   ratio > 20   → emit anchor markdown or JSON
#
# Exit codes:
#   0 = success (anchor emitted or skipped)
#   2 = input error

set -uo pipefail

RATIO=""
CURRENT_TASK=""
ACTIVE_SPEC=""
LAST_DECISION=""
NEXT_STEP=""
DEGRADED=""
JSON_OUT=false
FORCE=false

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ratio) RATIO="$2"; shift 2 ;;
    --current-task) CURRENT_TASK="$2"; shift 2 ;;
    --active-spec) ACTIVE_SPEC="$2"; shift 2 ;;
    --last-decision) LAST_DECISION="$2"; shift 2 ;;
    --next-step) NEXT_STEP="$2"; shift 2 ;;
    --degraded) DEGRADED="$2"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    --force) FORCE=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag $1" >&2; exit 2 ;;
  esac
done

[[ -z "$RATIO" ]] && { echo "Error: --ratio required" >&2; exit 2; }

# Validate ratio is numeric
if ! [[ "$RATIO" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Error: --ratio must be numeric, got '$RATIO'" >&2
  exit 2
fi

# ── Threshold check ──────────────────────────────────────────────────────────
RATIO_INT=$(awk -v r="$RATIO" 'BEGIN{printf "%d", r}')
if ! $FORCE && (( RATIO_INT <= 20 )); then
  if $JSON_OUT; then
    printf '{"skipped":true,"reason":"ratio_below_threshold","ratio":%s,"threshold":20}\n' "$RATIO"
  else
    echo "# ratio=${RATIO} below threshold (20), no anchor needed"
  fi
  exit 0
fi

# ── Default fallbacks ────────────────────────────────────────────────────────
[[ -z "$CURRENT_TASK" ]] && CURRENT_TASK="(unknown)"
[[ -z "$ACTIVE_SPEC" ]] && ACTIVE_SPEC="(none)"
[[ -z "$LAST_DECISION" ]] && LAST_DECISION="(none recorded)"
[[ -z "$NEXT_STEP" ]] && NEXT_STEP="(to be determined)"
[[ -z "$DEGRADED" ]] && DEGRADED="(none flagged)"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ── Emit anchor ──────────────────────────────────────────────────────────────
if $JSON_OUT; then
  # Escape JSON strings
  escape_json() { echo "$1" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip())[1:-1])" 2>/dev/null || echo "$1"; }
  printf '{"ratio":%s,"timestamp":"%s","current_task":"%s","active_spec":"%s","last_decision":"%s","next_step":"%s","degraded":"%s","emitted":true}\n' \
    "$RATIO" "$TIMESTAMP" \
    "$(escape_json "$CURRENT_TASK")" \
    "$(escape_json "$ACTIVE_SPEC")" \
    "$(escape_json "$LAST_DECISION")" \
    "$(escape_json "$NEXT_STEP")" \
    "$(escape_json "$DEGRADED")"
else
  cat <<ANCHOR
## Context Re-State (post-compaction, ${RATIO}:1)

**Timestamp**: ${TIMESTAMP}
**Current task**: ${CURRENT_TASK}
**Active spec**: ${ACTIVE_SPEC}
**Last decision**: ${LAST_DECISION}
**Next step**: ${NEXT_STEP}
**Degraded**: ${DEGRADED}

> Verify these facts above. If any drift is detected, re-state
> explicitly before continuing.
ANCHOR
fi

exit 0
