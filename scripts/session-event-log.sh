#!/usr/bin/env bash
set -uo pipefail
# session-event-log.sh — Managed Agents pattern: durable session log
#
# Inspired by Anthropic's "Context as External Object" pattern.
# Append-only event log that survives compaction. Unlike context window
# (ephemeral), this log is durable — events can be recovered after /compact.
#
# Usage:
#   bash scripts/session-event-log.sh emit "decision" "chose PostgreSQL for DB"
#   bash scripts/session-event-log.sh emit "correction" "use X not Y"
#   bash scripts/session-event-log.sh emit "discovery" "bug was caused by Z"
#   bash scripts/session-event-log.sh query --type decision --last 10
#   bash scripts/session-event-log.sh query --since 2026-04-14
#   bash scripts/session-event-log.sh recover --session latest
#   bash scripts/session-event-log.sh status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_LOG_DIR="${SESSION_LOG_DIR:-$HOME/.savia/session-events}"
SESSION_ID="${SAVIA_SESSION_ID:-$(date +%Y%m%d-%H%M%S)-$$}"

mkdir -p "$SESSION_LOG_DIR"

LOG_FILE="$SESSION_LOG_DIR/${SESSION_ID}.jsonl"

# ── Emit ───────────────────────────────────────────────────────────────────

cmd_emit() {
  local event_type="${1:-note}" content="${2:-}"

  if [[ -z "$content" ]]; then
    echo "Usage: session-event-log.sh emit <type> <content>" >&2
    echo "Types: decision, correction, discovery, tool_result, note, error" >&2
    return 1
  fi

  # Validate event type
  case "$event_type" in
    decision|correction|discovery|tool_result|note|error|milestone|handoff) ;;
    *) echo "WARN: Unknown event type '$event_type', using 'note'" >&2; event_type="note" ;;
  esac

  # Escape content for JSON
  local escaped_content
  escaped_content=$(printf '%s' "$content" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')

  # Multica pattern: monotonic seq number per session for catch-up queries
  local seq
  if [[ -f "$LOG_FILE" ]]; then
    seq=$(( $(wc -l < "$LOG_FILE") + 1 ))
  else
    seq=1
  fi

  printf '{"ts":"%s","session":"%s","seq":%d,"type":"%s","content":"%s"}\n' \
    "$(date -Iseconds)" "$SESSION_ID" "$seq" "$event_type" "$escaped_content" >> "$LOG_FILE"

  echo "OK: event logged (seq=$seq, type=$event_type, session=$SESSION_ID)"
}

# ── Query ──────────────────────────────────────────────────────────────────

cmd_query() {
  local filter_type="" last_n=0 since="" since_seq="" session_filter=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)       filter_type="$2"; shift 2 ;;
      --last)       last_n="$2"; shift 2 ;;
      --since)      since="$2"; shift 2 ;;
      --since-seq)  since_seq="$2"; shift 2 ;;
      --session)    session_filter="$2"; shift 2 ;;
      *)            shift ;;
    esac
  done

  local all_events=""

  # Scope: specific session file or all
  local source_files
  if [[ -n "$session_filter" ]]; then
    source_files="$SESSION_LOG_DIR/${session_filter}.jsonl"
    [[ ! -f "$source_files" ]] && { echo "Session not found: $session_filter" >&2; return 1; }
  else
    source_files="$SESSION_LOG_DIR"/*.jsonl
  fi

  # Collect events
  if [[ -n "$since" ]]; then
    all_events=$(cat $source_files 2>/dev/null | grep -E "\"ts\":\"${since}" || true)
  else
    all_events=$(cat $source_files 2>/dev/null || true)
  fi

  # Filter by type
  if [[ -n "$filter_type" ]]; then
    all_events=$(echo "$all_events" | grep "\"type\":\"${filter_type}\"" || true)
  fi

  # Multica catch-up pattern: filter by seq > since_seq
  if [[ -n "$since_seq" ]]; then
    all_events=$(echo "$all_events" | awk -v min_seq="$since_seq" '
      match($0, /"seq":[0-9]+/) {
        seq_val = substr($0, RSTART+6, RLENGTH-6)
        if (seq_val + 0 > min_seq + 0) print $0
      }
    ')
  fi

  # Limit results
  if (( last_n > 0 )); then
    echo "$all_events" | tail -"$last_n"
  else
    echo "$all_events"
  fi
}

# ── Recover ────────────────────────────────────────────────────────────────

cmd_recover() {
  local target="latest"

  # Parse args: support --session <id> or positional id
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session) target="$2"; shift 2 ;;
      recover)   shift ;;  # swallow command name if passed
      *)         target="$1"; shift ;;
    esac
  done

  if [[ "$target" == "latest" ]]; then
    local latest_log
    latest_log=$(ls -t "$SESSION_LOG_DIR"/*.jsonl 2>/dev/null | head -1)
    if [[ -z "$latest_log" ]]; then
      echo "No session logs found." >&2
      return 1
    fi
    target="$latest_log"
  elif [[ ! -f "$SESSION_LOG_DIR/${target}.jsonl" ]]; then
    echo "Session log not found: $target" >&2
    return 1
  else
    target="$SESSION_LOG_DIR/${target}.jsonl"
  fi

  echo "Session Recovery — $(basename "$target" .jsonl)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local total decisions corrections discoveries
  total=$(wc -l < "$target")
  decisions=$(grep -c '"type":"decision"' "$target" 2>/dev/null) || decisions=0
  corrections=$(grep -c '"type":"correction"' "$target" 2>/dev/null) || corrections=0
  discoveries=$(grep -c '"type":"discovery"' "$target" 2>/dev/null) || discoveries=0

  echo "  Total events:  $total"
  echo "  Decisions:     $decisions"
  echo "  Corrections:   $corrections"
  echo "  Discoveries:   $discoveries"
  echo ""

  # Show decisions and corrections (most valuable for recovery)
  if (( decisions > 0 )); then
    echo "## Decisions"
    grep '"type":"decision"' "$target" | while IFS= read -r line; do
      local ts content
      ts=$(echo "$line" | grep -oP '"ts":"[^"]*"' | cut -d'"' -f4 | cut -dT -f2 | cut -d+ -f1)
      content=$(echo "$line" | grep -oP '"content":"[^"]*"' | cut -d'"' -f4)
      echo "  [$ts] $content"
    done
    echo ""
  fi

  if (( corrections > 0 )); then
    echo "## Corrections"
    grep '"type":"correction"' "$target" | while IFS= read -r line; do
      local ts content
      ts=$(echo "$line" | grep -oP '"ts":"[^"]*"' | cut -d'"' -f4 | cut -dT -f2 | cut -d+ -f1)
      content=$(echo "$line" | grep -oP '"content":"[^"]*"' | cut -d'"' -f4)
      echo "  [$ts] $content"
    done
  fi
}

# ── Status ─────────────────────────────────────────────────────────────────

cmd_status() {
  echo "Session Event Log (Managed Agents pattern)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Log dir:        $SESSION_LOG_DIR"
  echo "  Current session: $SESSION_ID"

  if [[ -f "$LOG_FILE" ]]; then
    echo "  Events today:   $(wc -l < "$LOG_FILE")"
  else
    echo "  Events today:   0 (no log yet)"
  fi

  local total_sessions total_events
  total_sessions=$(ls "$SESSION_LOG_DIR"/*.jsonl 2>/dev/null | wc -l || echo 0)
  total_events=$(cat "$SESSION_LOG_DIR"/*.jsonl 2>/dev/null | wc -l || echo 0)
  echo "  Total sessions: $total_sessions"
  echo "  Total events:   $total_events"

  # Size
  local size_kb
  size_kb=$(du -sk "$SESSION_LOG_DIR" 2>/dev/null | awk '{print $1}' || echo 0)
  echo "  Storage:        ${size_kb}KB"
}

# ── Main ───────────────────────────────────────────────────────────────────

case "${1:-status}" in
  emit)     shift; cmd_emit "$@" ;;
  query)    shift; cmd_query "$@" ;;
  recover)  shift; cmd_recover "$@" ;;
  status)   cmd_status ;;
  *)        echo "Usage: session-event-log.sh {emit|query|recover|status}" >&2; exit 1 ;;
esac
