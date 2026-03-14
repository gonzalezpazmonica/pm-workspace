#!/usr/bin/env bash
# pipeline-stage-runner.sh — Execute a single pipeline stage
# Usage: ./scripts/pipeline-stage-runner.sh --name NAME --command CMD [--agent AGENT] [--input INPUT] [--timeout SECS] [--output-dir DIR]
# ─────────────────────────────────────────────────────────────────
set -uo pipefail
cat /dev/stdin > /dev/null 2>&1 || true

NAME="" COMMAND="" AGENT="" INPUT="" TIMEOUT=300 OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --command) COMMAND="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -z "$NAME" ] && { echo "Error: --name required" >&2; exit 1; }

# ── Prepare output ──
[ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="output/pipeline-runs/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR" 2>/dev/null || true
STAGE_LOG="$OUTPUT_DIR/stage-${NAME}.log"
STAGE_RESULT="$OUTPUT_DIR/stage-${NAME}.json"

START_TS=$(date +%s)
STATUS="success"
EXIT_CODE=0

echo "=== Stage: $NAME ===" > "$STAGE_LOG"
echo "Started: $(date -Iseconds)" >> "$STAGE_LOG"

# ── Execute ──
if [ -n "$COMMAND" ]; then
  echo "Command: $COMMAND" >> "$STAGE_LOG"
  if timeout "$TIMEOUT" bash -c "$COMMAND" >> "$STAGE_LOG" 2>&1; then
    EXIT_CODE=0
  else
    EXIT_CODE=$?
    STATUS="failed"
  fi
elif [ -n "$AGENT" ]; then
  echo "Agent: $AGENT" >> "$STAGE_LOG"
  echo "Input: $INPUT" >> "$STAGE_LOG"
  # Agent execution is delegated to Claude — log placeholder
  echo "Agent stage requires Claude orchestration (dry-run in standalone mode)" >> "$STAGE_LOG"
  EXIT_CODE=0
else
  echo "Error: no --command or --agent specified" >> "$STAGE_LOG"
  STATUS="failed"
  EXIT_CODE=1
fi

END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

# ── Write result ──
cat > "$STAGE_RESULT" <<EOJSON
{
  "stage": "$NAME",
  "status": "$STATUS",
  "exit_code": $EXIT_CODE,
  "duration_seconds": $DURATION,
  "started": "$(date -d @$START_TS -Iseconds 2>/dev/null || date -r $START_TS -Iseconds 2>/dev/null || echo unknown)",
  "log": "stage-${NAME}.log"
}
EOJSON

echo "Completed: $STATUS (${DURATION}s)" >> "$STAGE_LOG"
echo "$STATUS"
exit $EXIT_CODE
