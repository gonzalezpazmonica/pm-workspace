#!/usr/bin/env bash
set -uo pipefail
# truth-tribunal-worker.sh — Consume queued Truth Tribunal verification
# requests (SPEC-106 Phase 2). Designed for one-shot run from cron or a
# manual /tribunal-process invocation. NOT a daemon.
#
# Pipeline per request:
#   1. Read .req file from queue
#   2. Detect report_type + destination_tier
#   3. Mark as in-progress (rename .req → .work)
#   4. Synchronously invoke the truth-tribunal-orchestrator agent path
#      (Phase 2 MVP: the worker only stages judges-dir + writes a .pending
#      placeholder; orchestrator-agent invocation is a follow-on step
#      because the worker runs outside Claude Code session context)
#   5. Move .work → .done on success, .work → .fail on error
#
# Subcommands:
#   worker.sh process [--max N]   — process up to N pending requests
#   worker.sh status              — show queue depth and last verdicts
#   worker.sh clean               — remove .done older than 7 days
#   worker.sh enqueue <report>    — manually enqueue a report
#
# Exit codes: 0 ok | 1 nothing to do | 2 usage error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TRIBUNAL_SH="$ROOT/scripts/truth-tribunal.sh"
QUEUE_DIR="${TRUTH_TRIBUNAL_QUEUE:-$HOME/.savia/truth-tribunal/queue}"
LOG_FILE="${TRUTH_TRIBUNAL_LOG:-$HOME/.savia/truth-tribunal/worker.log}"
MAX_PER_RUN="${TRUTH_TRIBUNAL_MAX_PER_RUN:-5}"

mkdir -p "$QUEUE_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() {
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "[$ts] $*" >> "$LOG_FILE"
}

# ── enqueue: manually add a report to the queue ───────────────────────────
do_enqueue() {
  local report="$1"
  [[ -z "$report" ]] && { echo "usage: worker.sh enqueue <report-path>" >&2; return 2; }
  [[ ! -f "$report" ]] && { echo "ERROR: report not found: $report" >&2; return 1; }

  local run_id="TT-$(date -u +%Y%m%d-%H%M%S)-$$"
  local req="$QUEUE_DIR/${run_id}.req"
  {
    echo "report_path=$report"
    echo "tool=manual"
    echo "queued_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$req"
  echo "Enqueued: $req"
  log "enqueue manual $report"
}

# ── status: show queue counts ─────────────────────────────────────────────
do_status() {
  local pending done_ct fail_ct work_ct
  pending=$(find "$QUEUE_DIR" -maxdepth 1 -name "*.req" 2>/dev/null | wc -l)
  work_ct=$(find "$QUEUE_DIR" -maxdepth 1 -name "*.work" 2>/dev/null | wc -l)
  done_ct=$(find "$QUEUE_DIR" -maxdepth 1 -name "*.done" 2>/dev/null | wc -l)
  fail_ct=$(find "$QUEUE_DIR" -maxdepth 1 -name "*.fail" 2>/dev/null | wc -l)
  echo "Truth Tribunal queue ($QUEUE_DIR):"
  echo "  pending:     $pending"
  echo "  in-progress: $work_ct"
  echo "  done:        $done_ct"
  echo "  failed:      $fail_ct"
  if [[ -f "$LOG_FILE" ]]; then
    echo
    echo "Last 5 log entries:"
    tail -5 "$LOG_FILE" | sed 's/^/  /'
  fi
}

# ── clean: remove old .done files ─────────────────────────────────────────
do_clean() {
  local count
  count=$(find "$QUEUE_DIR" -maxdepth 1 -name "*.done" -mtime +7 2>/dev/null | wc -l)
  find "$QUEUE_DIR" -maxdepth 1 -name "*.done" -mtime +7 -delete 2>/dev/null
  echo "Cleaned $count old .done files (>7 days)"
  log "clean $count"
}

# ── process: handle up to MAX pending requests ────────────────────────────
process_one() {
  local req="$1"
  local base="${req%.req}"
  local work="${base}.work"
  local done="${base}.done"
  local fail="${base}.fail"

  # Atomic rename to claim
  mv "$req" "$work" 2>/dev/null || return 0

  # Read request fields
  local report_path
  report_path=$(awk -F= '/^report_path=/{print substr($0, index($0,"=")+1)}' "$work")
  if [[ -z "$report_path" || ! -f "$report_path" ]]; then
    log "skip $work — report missing: $report_path"
    mv "$work" "$fail" 2>/dev/null
    return 1
  fi

  log "process $report_path"

  # Phase 2 worker behavior: stage the work but DON'T invoke judges directly
  # (judge agents must run inside Claude Code with API access). Instead,
  # write a `.pending` marker next to the report so /tribunal-status can
  # surface it and so the user can run /report-verify manually or so a
  # future Phase 2.5 in-session orchestrator can pick it up.
  local pending_marker="${report_path}.truth.pending"
  {
    echo "---"
    echo "queued_at: $(awk -F= '/^queued_at=/{print substr($0, index($0,"=")+1)}' "$work")"
    echo "claimed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "report_type: $(bash "$TRIBUNAL_SH" detect-type "$report_path" 2>/dev/null || echo default)"
    echo "destination_tier: $(bash "$TRIBUNAL_SH" detect-tier "$report_path" 2>/dev/null || echo N1)"
    echo "status: pending_evaluation"
    echo "next_action: run /report-verify $(basename "$report_path")"
    echo "---"
  } > "$pending_marker" 2>/dev/null

  mv "$work" "$done" 2>/dev/null
  log "marked pending $report_path"
  return 0
}

do_process() {
  local max="${1:-$MAX_PER_RUN}"
  local processed=0
  local req
  for req in $(find "$QUEUE_DIR" -maxdepth 1 -name "*.req" -type f 2>/dev/null | sort | head -n "$max"); do
    process_one "$req" && processed=$((processed + 1))
  done
  echo "Processed: $processed"
  [[ $processed -eq 0 ]] && return 1
  return 0
}

usage() {
  cat <<EOF
truth-tribunal-worker.sh — SPEC-106 Phase 2 queue worker

Usage:
  worker.sh process [--max N]    Process up to N pending requests (default $MAX_PER_RUN)
  worker.sh status               Show queue depth and recent activity
  worker.sh clean                Remove .done files older than 7 days
  worker.sh enqueue <report>     Manually enqueue a report

Queue: $QUEUE_DIR
Log:   $LOG_FILE
EOF
}

case "${1:-}" in
  process)
    shift
    if [[ "${1:-}" == "--max" ]]; then
      shift
      do_process "${1:-$MAX_PER_RUN}"
    else
      do_process "$MAX_PER_RUN"
    fi
    ;;
  status)  do_status ;;
  clean)   do_clean ;;
  enqueue) shift; do_enqueue "${1:-}" ;;
  help|-h|--help|"") usage ;;
  *) echo "Unknown subcommand: $1" >&2; usage >&2; exit 2 ;;
esac
