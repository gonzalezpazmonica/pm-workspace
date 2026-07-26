#!/usr/bin/env bash
set -uo pipefail
# trajectory-detector.sh — SE-273 S6: Detección de desviación en minutos
# Evalúa señales deterministas en-proceso (sin LLM) para detectar
# comportamiento anómalo. Respuesta graduada: anotar → preguntar → pausar.
# Usage: bash scripts/trajectory-detector.sh evaluate
# Master switch: SAVIA_TRAJECTORY_DETECTOR=off

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_DIR="${ROOT}/output/trajectory-state"
LOG="${ROOT}/output/trajectory-events.jsonl"
ACTION="${1:-evaluate}"

[[ "${SAVIA_TRAJECTORY_DETECTOR:-on}" == "off" ]] && exit 0
mkdir -p "$STATE_DIR"

# ── Signals (deterministic, no LLM cost) ────────────────────────────

# Signal 1: tool call rate per minute
get_tool_rate() {
  local window="${1:-5}"  # minutes
  local cutoff; cutoff=$(date -u -d "${window} minutes ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")
  local count=0
  [[ -f "$LOG" ]] && count=$(grep -c '"tool_call"' "$LOG" 2>/dev/null | head -1 || echo 0)
  # Approximate: use file modification time as proxy
  local rate=$(( count / (window > 0 ? window : 1) ))
  echo "$rate"
}

# Signal 2: novel action classes appearing (from S2 profile)
get_novel_actions() {
  local profile="${ROOT}/output/action-shape-profile.jsonl"
  [[ ! -f "$profile" ]] && echo 0 && return
  local window=10  # last 10 minutes
  local cutoff; cutoff=$(date -u -d "${window} minutes ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")
  # Count novel actions (nov=2) in window
  python3 -c "
import sys, json
cutoff = '$cutoff'
count = 0
try:
    with open('$profile') as f:
        for line in f:
            d = json.loads(line.strip())
            if d.get('ts', '') >= cutoff and d.get('nov', 0) >= 2:
                count += 1
except: pass
print(count)
" 2>/dev/null || echo 0
}

# Signal 3: denied egress attempts (from S3 log)
get_denied_egress() {
  local egress_log="${ROOT}/output/egress-denials.jsonl"
  [[ ! -f "$egress_log" ]] && echo 0 && return
  local window=5
  local cutoff; cutoff=$(date -u -d "${window} minutes ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")
  python3 -c "
import sys, json
cutoff = '$cutoff'
count = 0
try:
    with open('$egress_log') as f:
        for line in f:
            d = json.loads(line.strip())
            if d.get('ts', '') >= cutoff:
                count += 1
except: pass
print(count)
" 2>/dev/null || echo 0
}

# Signal 4: governed path access attempts
get_governed_touches() {
  local trigger_log="${ROOT}/output/judge-triggers.jsonl"
  [[ ! -f "$trigger_log" ]] && echo 0 && return
  python3 -c "
import sys, json
count = 0
try:
    with open('$trigger_log') as f:
        for line in f:
            d = json.loads(line.strip())
            if 'rule-violation' in d.get('judge', ''):
                count += 1
except: pass
print(count)
" 2>/dev/null || echo 0
}

# ── Anomaly evaluation ──────────────────────────────────────────────
do_evaluate() {
  local tool_rate; tool_rate=$(get_tool_rate)
  local novel; novel=$(get_novel_actions)
  local denied; denied=$(get_denied_egress)
  local governed; governed=$(get_governed_touches)
  
  local severity=0  # 0=normal, 1=annotate, 2=ask, 3=pause
  
  # Rate anomaly: >20 tool calls/min
  [[ "$tool_rate" -gt 20 ]] && severity=1
  [[ "$tool_rate" -gt 50 ]] && severity=2
  
  # Novel actions in short window
  [[ "$novel" -ge 2 ]] && severity=1
  [[ "$novel" -ge 5 ]] && severity=2
  
  # Denied egress attempts
  [[ "$denied" -ge 1 ]] && severity=2
  [[ "$denied" -ge 3 ]] && severity=3
  
  # Governed path touches
  [[ "$governed" -ge 1 ]] && severity=2
  [[ "$governed" -ge 3 ]] && severity=3
  
  # Combined: novel + denied = severe
  [[ "$novel" -ge 2 && "$denied" -ge 1 ]] && severity=3
  
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local level
  case $severity in
    0) level="normal" ;;
    1) level="annotate" ;;
    2) level="ask" ;;
    3) level="pause" ;;
  esac
  
  echo "{\"ts\":\"$ts\",\"level\":\"$level\",\"severity\":$severity,\"signals\":{\"tool_rate\":$tool_rate,\"novel_actions\":$novel,\"denied_egress\":$denied,\"governed_touches\":$governed}}" >> "$LOG"
  
  case $severity in
    0) echo "TRAJECTORY: normal" ;;
    1) echo "TRAJECTORY: annotate — rate=$tool_rate novel=$novel" >&2 ;;
    2) 
      echo "TRAJECTORY: ask — rate=$tool_rate novel=$novel denied=$denied governed=$governed" >&2
      echo "Desviación moderada detectada. ¿Continuar?" >&2
      ;;
    3)
      echo "TRAJECTORY: PAUSE — rate=$tool_rate novel=$novel denied=$denied governed=$governed" >&2
      echo "Desviación severa detectada. Ejecución pausada." >&2
      echo "Señales: acciones novedosas + intentos de egreso denegados." >&2
      echo "Para continuar: confirma que este comportamiento es esperado." >&2
      exit 3
      ;;
  esac
}

do_status() {
  echo "=== Trajectory Detector Status (SE-273 S6) ==="
  echo "Rate (5min): $(get_tool_rate) calls/min"
  echo "Novel actions (10min): $(get_novel_actions)"
  echo "Denied egress (5min): $(get_denied_egress)"
  echo "Governed touches: $(get_governed_touches)"
  [[ -f "$LOG" ]] && echo "Events: $(wc -l < "$LOG")" || echo "Events: 0"
}

case "$ACTION" in
  evaluate) do_evaluate ;;
  status) do_status ;;
  *) echo "Usage: $0 {evaluate|status}" >&2; exit 2 ;;
esac
