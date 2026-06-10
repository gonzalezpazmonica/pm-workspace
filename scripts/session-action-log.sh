#!/usr/bin/env bash
# session-action-log.sh — Append-only session action log (SPEC-065)
# Usage: session-action-log.sh log|attempts|history|reset [args]
set -uo pipefail

LOG_FILE="${SESSION_ACTION_LOG:-output/session-action-log.jsonl}"
SESSION_ID="${SESSION_ACTION_SESSION:-$$}"

cmd="${1:-help}"; shift || true

log_entry() {
  local action="${1:?action required}" target="${2:?target required}"
  local result="${3:?result required}" detail="${4:-}"
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
  local attempt
  attempt=$(count_attempts "$action" "$target")
  [[ "$result" == "fail" || "$result" == "error" ]] && attempt=$((attempt + 1))
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "now")
  printf '{"ts":"%s","action":"%s","target":"%s","result":"%s","detail":"%s","attempt":%d,"session":"%s"}\n' \
    "$ts" "$action" "$target" "$result" "$detail" "$attempt" "$SESSION_ID" >> "$LOG_FILE"
  echo "$attempt"
}

count_attempts() {
  local action="$1" target="$2"
  [[ ! -f "$LOG_FILE" ]] && echo 0 && return
  local count=0
  while IFS= read -r line; do
    local la lt lr ls
    la=$(echo "$line" | sed -n 's/.*"action":"\([^"]*\)".*/\1/p')
    lt=$(echo "$line" | sed -n 's/.*"target":"\([^"]*\)".*/\1/p')
    lr=$(echo "$line" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')
    ls=$(echo "$line" | sed -n 's/.*"session":"\([^"]*\)".*/\1/p')
    if [[ "$la" == "$action" && "$lt" == "$target" && "$ls" == "$SESSION_ID" ]]; then
      if [[ "$lr" == "fail" || "$lr" == "error" ]]; then
        count=$((count + 1))
      fi
    fi
  done < "$LOG_FILE"
  echo "$count"
}

show_history() {
  local action="${1:-}"
  [[ ! -f "$LOG_FILE" ]] && echo "No log file." && return
  if [[ -n "$action" ]]; then
    grep "\"action\":\"$action\"" "$LOG_FILE" | tail -10
  else
    tail -10 "$LOG_FILE"
  fi
}

get_details() {
  local action="$1" target="$2" max="${3:-10}"
  [[ ! -f "$LOG_FILE" ]] && return
  while IFS= read -r line; do
    local la lt lr ls
    la=$(echo "$line" | sed -n 's/.*"action":"\([^"]*\)".*/\1/p')
    lt=$(echo "$line" | sed -n 's/.*"target":"\([^"]*\)".*/\1/p')
    lr=$(echo "$line" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')
    ls=$(echo "$line" | sed -n 's/.*"session":"\([^"]*\)".*/\1/p')
    if [[ "$la" == "$action" && "$lt" == "$target" && "$ls" == "$SESSION_ID" && "$lr" == "fail" ]]; then
      echo "$line" | sed -n 's/.*"detail":"\([^"]*\)".*/\1/p'
    fi
  done < "$LOG_FILE" | tail -"$max"
}

flush_log() {
  local mode="best"
  # Parse --mode flag or positional
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode) mode="${2:-best}"; shift 2 ;;
      best|fast) mode="$1"; shift ;;
      *) echo "ERROR: unknown argument '$1'" >&2; exit 2 ;;
    esac
  done
  [[ "$mode" != "best" && "$mode" != "fast" ]] && echo "ERROR: mode must be 'best' or 'fast'" >&2 && exit 2
  [[ ! -f "$LOG_FILE" ]] && echo "WARN: no log file to flush" >&2 && exit 0

  local level=9
  [[ "$mode" == "fast" ]] && level=3

  command -v zstd >/dev/null 2>&1 || { echo "WARN: zstd not available — flush skipped" >&2; exit 0; }

  local out="${LOG_FILE}.zst"
  zstd -"$level" -f -q "$LOG_FILE" -o "$out" 2>/dev/null || { echo "WARN: zstd failed — flush skipped" >&2; exit 0; }
  echo "FLUSHED mode=$mode file=$out size=$(wc -c < "$out" 2>/dev/null || echo '?')" >&2
}

case "$cmd" in
  log)      log_entry "$@" ;;
  attempts) count_attempts "${1:?action}" "${2:?target}" ;;
  details)  get_details "${1:?action}" "${2:?target}" "${3:-10}" ;;
  history)  show_history "${1:-}" ;;
  reset)    rm -f "$LOG_FILE"; echo "Log cleared." ;;
  flush)    flush_log "$@" ;;
  help|*)   echo "Usage: $0 log|attempts|details|history|reset|flush [args]" ;;
esac
