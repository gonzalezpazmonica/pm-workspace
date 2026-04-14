#!/usr/bin/env bash
set -uo pipefail
# session-resume-index.sh — Multica pattern: session resumption metadata
#
# Inspired by Multica's task_message table (daemon.go) where the daemon
# stores (agent_type, spec_id) → last_session_id so agents can catch up
# after disconnect without starting fresh.
#
# Storage: TSV for grep-friendliness. One line per (agent_type, spec_id).
# Last write wins (latest session_id kept).
#
# Usage:
#   bash scripts/session-resume-index.sh record <agent_type> <spec_id> <session_id> [work_dir]
#   bash scripts/session-resume-index.sh lookup <agent_type> <spec_id>
#   bash scripts/session-resume-index.sh list [--agent <type>] [--spec <id>]
#   bash scripts/session-resume-index.sh forget <agent_type> <spec_id>
#   bash scripts/session-resume-index.sh status

INDEX_FILE="${SESSION_RESUME_INDEX:-$HOME/.savia/session-resume-index.tsv}"

mkdir -p "$(dirname "$INDEX_FILE")"
touch "$INDEX_FILE"

# ── Record ─────────────────────────────────────────────────────────────────

cmd_record() {
  local agent_type="${1:-}" spec_id="${2:-}" session_id="${3:-}" work_dir="${4:-}"

  if [[ -z "$agent_type" || -z "$spec_id" || -z "$session_id" ]]; then
    echo "Usage: session-resume-index.sh record <agent_type> <spec_id> <session_id> [work_dir]" >&2
    return 1
  fi

  # Remove existing entry for this (agent_type, spec_id) — last write wins
  local tmp
  tmp=$(mktemp)
  grep -v "^${agent_type}	${spec_id}	" "$INDEX_FILE" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$INDEX_FILE"

  # Append new entry
  local ts
  ts=$(date -Iseconds)
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$agent_type" "$spec_id" "$session_id" "$ts" "$work_dir" >> "$INDEX_FILE"

  echo "OK: recorded (agent=$agent_type, spec=$spec_id, session=$session_id)"
}

# ── Lookup ─────────────────────────────────────────────────────────────────

cmd_lookup() {
  local agent_type="${1:-}" spec_id="${2:-}"

  if [[ -z "$agent_type" || -z "$spec_id" ]]; then
    echo "Usage: session-resume-index.sh lookup <agent_type> <spec_id>" >&2
    return 1
  fi

  local match
  match=$(grep "^${agent_type}	${spec_id}	" "$INDEX_FILE" 2>/dev/null | tail -1)

  if [[ -z "$match" ]]; then
    echo "NOT_FOUND: no prior session for (agent=$agent_type, spec=$spec_id)" >&2
    return 1
  fi

  # Output: session_id, timestamp, work_dir (tab-separated for script consumption)
  local session_id ts work_dir
  session_id=$(echo "$match" | cut -f3)
  ts=$(echo "$match" | cut -f4)
  work_dir=$(echo "$match" | cut -f5)

  printf 'session_id=%s\n' "$session_id"
  printf 'timestamp=%s\n' "$ts"
  printf 'work_dir=%s\n' "$work_dir"
}

# ── List ───────────────────────────────────────────────────────────────────

cmd_list() {
  local filter_agent="" filter_spec=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) filter_agent="$2"; shift 2 ;;
      --spec)  filter_spec="$2"; shift 2 ;;
      *)       shift ;;
    esac
  done

  local entries="$INDEX_FILE"
  local result
  result=$(cat "$entries" 2>/dev/null || true)

  [[ -n "$filter_agent" ]] && result=$(echo "$result" | awk -F'\t' -v a="$filter_agent" '$1==a')
  [[ -n "$filter_spec" ]] && result=$(echo "$result" | awk -F'\t' -v s="$filter_spec" '$2==s')

  if [[ -z "$result" ]]; then
    echo "(no entries)"
    return 0
  fi

  printf '%-25s %-20s %-30s %s\n' "AGENT" "SPEC" "SESSION" "TIMESTAMP"
  echo "$result" | while IFS=$'\t' read -r agent spec session ts _; do
    printf '%-25s %-20s %-30s %s\n' "$agent" "$spec" "$session" "$ts"
  done
}

# ── Forget ─────────────────────────────────────────────────────────────────

cmd_forget() {
  local agent_type="${1:-}" spec_id="${2:-}"

  if [[ -z "$agent_type" || -z "$spec_id" ]]; then
    echo "Usage: session-resume-index.sh forget <agent_type> <spec_id>" >&2
    return 1
  fi

  local before after
  before=$(wc -l < "$INDEX_FILE")

  local tmp
  tmp=$(mktemp)
  grep -v "^${agent_type}	${spec_id}	" "$INDEX_FILE" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$INDEX_FILE"

  after=$(wc -l < "$INDEX_FILE")

  if (( before > after )); then
    echo "OK: forgot (agent=$agent_type, spec=$spec_id)"
  else
    echo "NOT_FOUND: no entry for (agent=$agent_type, spec=$spec_id)" >&2
    return 1
  fi
}

# ── Status ─────────────────────────────────────────────────────────────────

cmd_status() {
  echo "Session Resume Index (Multica pattern)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Index file: $INDEX_FILE"

  local count
  count=$(wc -l < "$INDEX_FILE" 2>/dev/null || echo 0)
  echo "  Entries:    $count"

  if (( count > 0 )); then
    local agents specs
    agents=$(cut -f1 "$INDEX_FILE" | sort -u | wc -l)
    specs=$(cut -f2 "$INDEX_FILE" | sort -u | wc -l)
    echo "  Agents:     $agents distinct"
    echo "  Specs:      $specs distinct"
    echo ""
    echo "  Latest 3 entries:"
    tail -3 "$INDEX_FILE" | while IFS=$'\t' read -r agent spec session ts _; do
      printf '    %s | %s | %s | %s\n' "$agent" "$spec" "$session" "$ts"
    done
  fi
}

# ── Main ───────────────────────────────────────────────────────────────────

case "${1:-status}" in
  record)  shift; cmd_record "$@" ;;
  lookup)  shift; cmd_lookup "$@" ;;
  list)    shift; cmd_list "$@" ;;
  forget)  shift; cmd_forget "$@" ;;
  status)  cmd_status ;;
  *)       echo "Usage: session-resume-index.sh {record|lookup|list|forget|status}" >&2; exit 1 ;;
esac
