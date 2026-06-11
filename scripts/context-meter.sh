#!/usr/bin/env bash
set -uo pipefail
# context-meter.sh — SE-219 S2: context window % as first-class metric (abtop pattern)
# Ref: docs/propuestas/SE-219-abtop-patterns.md
# Usage: context-meter.sh [--json] [--threshold-warn N] [--threshold-critical N]
# Exit: 0 always

THRESHOLD_WARN="${CONTEXT_METER_WARN:-70}"
THRESHOLD_CRITICAL="${CONTEXT_METER_CRITICAL:-85}"
OUTPUT_JSON=false
SNAPSHOT_FILE="output/context-snapshot.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) OUTPUT_JSON=true; shift ;;
    --threshold-warn)
      THRESHOLD_WARN="${2:?--threshold-warn requires a value}"
      shift 2 ;;
    --threshold-critical)
      THRESHOLD_CRITICAL="${2:?--threshold-critical requires a value}"
      shift 2 ;;
    --help|-h)
      echo "Usage: context-meter.sh [--json] [--threshold-warn N] [--threshold-critical N]"
      exit 0 ;;
    *) shift ;;
  esac
done

# ── Resolve token counts ──────────────────────────────────────────────────────
USED=0
MAX=0
SOURCE="unknown"

if [[ -n "${CONTEXT_WINDOW_USED:-}" && -n "${CONTEXT_WINDOW_MAX:-}" ]]; then
  USED="${CONTEXT_WINDOW_USED}"
  MAX="${CONTEXT_WINDOW_MAX}"
  SOURCE="env"
elif [[ -f "$SNAPSHOT_FILE" ]]; then
  # Try to parse snapshot JSON with python3 (no jq dependency)
  read_snap() {
    python3 - "$SNAPSHOT_FILE" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(int(d.get("used", 0)))
    print(int(d.get("max", 0)))
except Exception:
    print(0); print(0)
PY
  }
  mapfile -t snap < <(read_snap) 2>/dev/null || true
  USED="${snap[0]:-0}"
  MAX="${snap[1]:-0}"
  [[ "$MAX" -gt 0 ]] && SOURCE="snapshot"
fi

# ── Calculate PCT ─────────────────────────────────────────────────────────────
PCT=0
STATUS="unknown"

if [[ "$MAX" -gt 0 ]] 2>/dev/null; then
  PCT=$(( USED * 100 / MAX ))
  # Clamp to 0-100
  [[ "$PCT" -gt 100 ]] && PCT=100
  [[ "$PCT" -lt 0 ]]   && PCT=0

  if   [[ "$PCT" -ge "$THRESHOLD_CRITICAL" ]]; then STATUS="critical"
  elif [[ "$PCT" -ge "$THRESHOLD_WARN"     ]]; then STATUS="warn"
  else                                              STATUS="ok"
  fi
fi

# ── Output ────────────────────────────────────────────────────────────────────
if $OUTPUT_JSON; then
  python3 - <<PY
import json
print(json.dumps({
    "pct":    $PCT,
    "used":   $USED,
    "max":    $MAX,
    "status": "$STATUS"
}))
PY
else
  echo "CONTEXT_PCT=${PCT}"
  echo "CONTEXT_TOKENS_USED=${USED}"
  echo "CONTEXT_TOKENS_MAX=${MAX}"
  echo "CONTEXT_STATUS=${STATUS}"
fi

exit 0
