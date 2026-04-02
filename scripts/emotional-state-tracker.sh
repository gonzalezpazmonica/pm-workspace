#!/bin/bash
set -uo pipefail
# emotional-state-tracker.sh — Track session stress state for Savia
# Source: Anthropic Research "Emotion concepts and their function in a LLM" (2026-04-02)
# Usage: bash scripts/emotional-state-tracker.sh {record|score|reset|status} [event]
# Events: retry, failure, escalation, context_high, rule_skip
# State: $HOME/.savia/session-stress.json (session-scoped, never in git)

STATE_DIR="${HOME}/.savia"
STATE_FILE="${STATE_DIR}/session-stress.json"

# Weights per event type (higher = more stress impact)
declare -A WEIGHTS=(
  [retry]=1
  [failure]=2
  [escalation]=3
  [context_high]=1
  [rule_skip]=3
)

ensure_state() {
  mkdir -p "$STATE_DIR"
  if [[ ! -f "$STATE_FILE" ]]; then
    cat > "$STATE_FILE" << 'EOF'
{"retry":0,"failure":0,"escalation":0,"context_high":0,"rule_skip":0,"session_start":"","last_event":""}
EOF
  fi
  # Set session_start if empty
  local start
  start=$(grep -o '"session_start":"[^"]*"' "$STATE_FILE" | cut -d'"' -f4)
  if [[ -z "$start" ]]; then
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local tmp
    tmp=$(sed "s/\"session_start\":\"[^\"]*\"/\"session_start\":\"$now\"/" "$STATE_FILE")
    printf '%s\n' "$tmp" > "$STATE_FILE"
  fi
}

cmd_record() {
  local event="${1:-}"
  if [[ -z "$event" ]]; then
    echo "Usage: $0 record {retry|failure|escalation|context_high|rule_skip}" >&2
    exit 1
  fi
  if [[ -z "${WEIGHTS[$event]+x}" ]]; then
    echo "Unknown event: $event. Valid: retry, failure, escalation, context_high, rule_skip" >&2
    exit 1
  fi
  ensure_state
  # Increment the event counter using sed (no jq dependency)
  local current
  current=$(grep -o "\"$event\":[0-9]*" "$STATE_FILE" | cut -d: -f2)
  current=${current:-0}
  local new=$((current + 1))
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local tmp
  tmp=$(sed "s/\"$event\":$current/\"$event\":$new/" "$STATE_FILE")
  tmp=$(echo "$tmp" | sed "s/\"last_event\":\"[^\"]*\"/\"last_event\":\"$event@$now\"/")
  printf '%s\n' "$tmp" > "$STATE_FILE"
  echo "Recorded: $event (count: $new)"
}

cmd_score() {
  ensure_state
  local total=0
  for event in retry failure escalation context_high rule_skip; do
    local count
    count=$(grep -o "\"$event\":[0-9]*" "$STATE_FILE" | cut -d: -f2)
    count=${count:-0}
    local weight=${WEIGHTS[$event]}
    total=$((total + count * weight))
  done
  # Normalize to 0-10 scale
  # Calibration: 5 retries + 2 failures + 1 escalation = score 5 (significant friction)
  # That's 5*1 + 2*2 + 1*3 = 12 raw → 5/10
  # So: raw 24+ → score 10
  local score
  if [[ $total -ge 24 ]]; then
    score=10
  else
    # Linear scale: raw/2.4, rounded
    score=$(( (total * 10 + 12) / 24 ))
    [[ $score -gt 10 ]] && score=10
  fi
  echo "$score"
}

cmd_reset() {
  ensure_state
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$STATE_FILE" << EOF
{"retry":0,"failure":0,"escalation":0,"context_high":0,"rule_skip":0,"session_start":"$now","last_event":""}
EOF
  echo "State reset."
}

cmd_status() {
  ensure_state
  local score
  score=$(cmd_score)
  local retry failure escalation context_high rule_skip last_event
  retry=$(grep -o '"retry":[0-9]*' "$STATE_FILE" | cut -d: -f2)
  failure=$(grep -o '"failure":[0-9]*' "$STATE_FILE" | cut -d: -f2)
  escalation=$(grep -o '"escalation":[0-9]*' "$STATE_FILE" | cut -d: -f2)
  context_high=$(grep -o '"context_high":[0-9]*' "$STATE_FILE" | cut -d: -f2)
  rule_skip=$(grep -o '"rule_skip":[0-9]*' "$STATE_FILE" | cut -d: -f2)
  last_event=$(grep -o '"last_event":"[^"]*"' "$STATE_FILE" | cut -d'"' -f4)

  local level="calm"
  if [[ $score -ge 9 ]]; then level="overload"
  elif [[ $score -ge 7 ]]; then level="high_stress"
  elif [[ $score -ge 5 ]]; then level="significant_friction"
  elif [[ $score -ge 3 ]]; then level="mild_friction"
  fi

  cat << EOF
Frustration score: $score/10 ($level)
  retry:        ${retry:-0}
  failure:      ${failure:-0}
  escalation:   ${escalation:-0}
  context_high: ${context_high:-0}
  rule_skip:    ${rule_skip:-0}
  last_event:   ${last_event:-none}
EOF
}

# ── Main ──
CMD="${1:-status}"
shift 2>/dev/null || true

case "$CMD" in
  record) cmd_record "$@" ;;
  score)  cmd_score ;;
  reset)  cmd_reset ;;
  status) cmd_status ;;
  *)
    echo "Usage: $0 {record|score|reset|status} [event]" >&2
    exit 1
    ;;
esac
