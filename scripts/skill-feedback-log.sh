#!/usr/bin/env bash
set -euo pipefail
# skill-feedback-log.sh — Append skill invocation to JSONL log
# Usage: skill-feedback-log.sh --skill NAME --command CMD --outcome success|failure|partial [options]

SKILL="" CMD="" OUTCOME="" PROJECT="" DURATION=0 FEEDBACK="" CONTEXT_PCT=0 TEST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) SKILL="$2"; shift 2 ;; --command) CMD="$2"; shift 2 ;;
    --outcome) OUTCOME="$2"; shift 2 ;; --project) PROJECT="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;; --feedback) FEEDBACK="$2"; shift 2 ;;
    --context-pct) CONTEXT_PCT="$2"; shift 2 ;; --test) TEST=true; shift ;; *) shift ;;
  esac
done

LOG_DIR="data"; LOG_FILE="$LOG_DIR/skill-invocations.jsonl"
mkdir -p "$LOG_DIR" 2>/dev/null || true

if $TEST; then
  echo '{"skill":"__test__","command":"test","timestamp":"2026-01-01T00:00:00Z","outcome":"success"}' >> "$LOG_FILE"
  tail -1 "$LOG_FILE" | grep -q "__test__" && { sed -i '/__test__/d' "$LOG_FILE"; echo "OK"; exit 0; }
  echo "FAIL: test entry not found" >&2; exit 1
fi

[[ -z "$SKILL" || -z "$CMD" || -z "$OUTCOME" ]] && { echo "Required: --skill --command --outcome" >&2; exit 1; }

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")
PROJ_JSON="null"; [[ -n "$PROJECT" ]] && PROJ_JSON="\"$PROJECT\""
FB_JSON="null"; [[ -n "$FEEDBACK" ]] && FB_JSON="\"$FEEDBACK\""

ENTRY="{\"skill\":\"$SKILL\",\"command\":\"$CMD\",\"timestamp\":\"$TS\",\"project\":$PROJ_JSON,\"outcome\":\"$OUTCOME\",\"duration_ms\":$DURATION,\"user_feedback\":$FB_JSON,\"context_pct\":$CONTEXT_PCT}"
echo "$ENTRY" >> "$LOG_FILE"

# Rotation at 2MB
FILE_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
if [[ $FILE_SIZE -gt 2097152 ]]; then
  ROTATED="$LOG_DIR/skill-invocations-$(date +%Y%m%d).jsonl"
  mv "$LOG_FILE" "$ROTATED"
  gzip "$ROTATED" 2>/dev/null || true
  touch "$LOG_FILE"
  # Keep max 10 rotated files
  ls -t "$LOG_DIR"/skill-invocations-*.jsonl.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
fi
exit 0
