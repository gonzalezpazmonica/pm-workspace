#!/usr/bin/env bash
# agent-run-log.sh — SE-217 Slice 1: append-only agent experiment log
# Ref: docs/propuestas/SE-217-autoresearch-patterns.md
set -uo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
DATE=$(date -u +%Y-%m-%d)
LOG_DIR="${AGENT_RUN_LOG_DIR:-output}"
LOG_FILE="${AGENT_RUN_LOG_FILE:-${LOG_DIR}/agent-run-log-${DATE}.tsv}"
HEADER="run_id	task	status	score	metric	commit	elapsed_s	hypothesis	description	ts"

# ── Helpers ─────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") <subcommand> [options]

Subcommands:
  start    --run-id ID --task T --hypothesis H
           Append a new pending entry.

  keep     --run-id ID --task T --commit C --score N --metric M --description D
           Update the matching pending entry to status=keep.

  discard  --run-id ID --task T --reason R
           Update the matching pending entry to status=discard.

  crash    --run-id ID --task T --error E
           Update the matching pending entry to status=crash.

  summary  --run-id ID
           Print totals: total / keep / discard / crash / keep_rate%.

  list     List unique run_ids with dates and counts.

Ref: docs/propuestas/SE-217-autoresearch-patterns.md
EOF
  exit 1
}

now_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

ensure_log() {
  mkdir -p "$LOG_DIR"
  if [[ ! -f "$LOG_FILE" ]]; then
    printf '%s\n' "$HEADER" > "$LOG_FILE"
  fi
}

# Atomic write: write to tempfile in same dir then mv (POSIX rename is atomic).
atomic_write() {
  local target="$1" content="$2"
  local tmp
  tmp=$(mktemp "${target}.XXXXXX")
  printf '%s' "$content" > "$tmp"
  mv "$tmp" "$target"
}

# Use awk to extract a single TSV field (1-based index).
# Preserves empty fields unlike IFS=$'\t' read (which collapses consecutive separators).
tsv_field() {
  local line="$1" idx="$2"
  printf '%s' "$line" | awk -F'\t' -v i="$idx" '{print $i}'
}

# Read the whole file, replace matching pending row, atomic-write back.
# $1=run_id $2=task $3=new_status $4=score $5=metric $6=commit $7=description
update_row() {
  local run_id="$1" task="$2" new_status="$3"
  local score="${4:-}" metric="${5:-}" commit="${6:-}" description="${7:-}"

  ensure_log

  # flock for atomic read-modify-write (AC-07)
  (
    flock -x 200

    local found=0
    local new_lines=()

    while IFS= read -r line; do
      # Pass header through unchanged
      if [[ "$line" == "run_id	"* ]]; then
        new_lines+=("$line")
        continue
      fi

      # Extract fields with awk (preserves empty fields)
      local f_run_id f_task f_status f_hypothesis f_ts
      f_run_id=$(tsv_field "$line" 1)
      f_task=$(tsv_field "$line" 2)
      f_status=$(tsv_field "$line" 3)
      f_hypothesis=$(tsv_field "$line" 8)
      f_ts=$(tsv_field "$line" 10)

      if [[ "$f_run_id" == "$run_id" && "$f_task" == "$task" && "$f_status" == "pending" && $found -eq 0 ]]; then
        found=1

        # Calculate elapsed_s from start ts
        local elapsed=""
        if [[ -n "$f_ts" ]]; then
          local start_epoch now_epoch
          start_epoch=$(date -u -d "$f_ts" +%s 2>/dev/null || echo "0")
          now_epoch=$(date -u +%s)
          elapsed=$(( now_epoch - start_epoch ))
          [[ "$elapsed" -lt 0 ]] && elapsed=0
        fi

        local ts; ts=$(now_ts)
        # Build updated row (tab-separated, empty fields stay empty)
        new_lines+=("${run_id}	${task}	${new_status}	${score}	${metric}	${commit}	${elapsed}	${f_hypothesis}	${description}	${ts}")
      else
        new_lines+=("$line")
      fi
    done < "$LOG_FILE"

    if [[ $found -eq 0 ]]; then
      echo "ERROR: No pending entry found for run_id='${run_id}' task='${task}'" >&2
      exit 1
    fi

    local content
    content=$(printf '%s\n' "${new_lines[@]}")
    atomic_write "$LOG_FILE" "$content"$'\n'

  ) 200>"${LOG_FILE}.lock"
}

# ── Subcommands ──────────────────────────────────────────────────────────────

cmd_start() {
  local run_id="" task="" hypothesis=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id)     run_id="$2";     shift 2 ;;
      --task)       task="$2";       shift 2 ;;
      --hypothesis) hypothesis="$2"; shift 2 ;;
      *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$run_id" ]]     && { echo "ERROR: --run-id is required" >&2; exit 1; }
  [[ -z "$task" ]]       && { echo "ERROR: --task is required" >&2; exit 1; }
  [[ -z "$hypothesis" ]] && { echo "ERROR: --hypothesis is required" >&2; exit 1; }

  ensure_log

  local ts; ts=$(now_ts)
  # Columns: run_id task status score metric commit elapsed_s hypothesis description ts
  # elapsed_s is empty at start; ts records the start time for elapsed calculation on keep/discard/crash
  local row="${run_id}	${task}	pending		quality-score			${hypothesis}		${ts}"

  (
    flock -x 200
    printf '%s\n' "$row" >> "$LOG_FILE"
  ) 200>"${LOG_FILE}.lock"
}

cmd_keep() {
  local run_id="" task="" commit="" score="" metric="quality-score" description=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id)      run_id="$2";      shift 2 ;;
      --task)        task="$2";        shift 2 ;;
      --commit)      commit="$2";      shift 2 ;;
      --score)       score="$2";       shift 2 ;;
      --metric)      metric="$2";      shift 2 ;;
      --description) description="$2"; shift 2 ;;
      *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$run_id" ]] && { echo "ERROR: --run-id is required" >&2; exit 1; }
  [[ -z "$task" ]]   && { echo "ERROR: --task is required" >&2; exit 1; }

  update_row "$run_id" "$task" "keep" "$score" "$metric" "$commit" "$description"
}

cmd_discard() {
  local run_id="" task="" reason=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id) run_id="$2"; shift 2 ;;
      --task)   task="$2";   shift 2 ;;
      --reason) reason="$2"; shift 2 ;;
      *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$run_id" ]] && { echo "ERROR: --run-id is required" >&2; exit 1; }
  [[ -z "$task" ]]   && { echo "ERROR: --task is required" >&2; exit 1; }

  update_row "$run_id" "$task" "discard" "" "" "" "$reason"
}

cmd_crash() {
  local run_id="" task="" error=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id) run_id="$2"; shift 2 ;;
      --task)   task="$2";   shift 2 ;;
      --error)  error="$2";  shift 2 ;;
      *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$run_id" ]] && { echo "ERROR: --run-id is required" >&2; exit 1; }
  [[ -z "$task" ]]   && { echo "ERROR: --task is required" >&2; exit 1; }

  update_row "$run_id" "$task" "crash" "" "" "" "$error"
}

cmd_summary() {
  local run_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id) run_id="$2"; shift 2 ;;
      *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  [[ -z "$run_id" ]] && { echo "ERROR: --run-id is required" >&2; exit 1; }

  if [[ ! -f "$LOG_FILE" ]]; then
    echo "No log file found: $LOG_FILE" >&2
    exit 1
  fi

  local total=0 keep=0 discard=0 crash=0
  while IFS= read -r line; do
    [[ "$line" == "run_id	"* ]] && continue
    local f_run_id f_status
    f_run_id=$(tsv_field "$line" 1)
    f_status=$(tsv_field "$line" 3)
    [[ "$f_run_id" != "$run_id" ]] && continue
    total=$(( total + 1 ))
    case "$f_status" in
      keep)    keep=$(( keep + 1 )) ;;
      discard) discard=$(( discard + 1 )) ;;
      crash)   crash=$(( crash + 1 )) ;;
    esac
  done < "$LOG_FILE"

  local keep_rate=0
  if [[ $total -gt 0 ]]; then
    keep_rate=$(( keep * 100 / total ))
  fi

  printf 'run_id:     %s\n' "$run_id"
  printf 'total:      %d\n' "$total"
  printf 'keep:       %d\n' "$keep"
  printf 'discard:    %d\n' "$discard"
  printf 'crash:      %d\n' "$crash"
  printf 'keep_rate:  %d%%\n' "$keep_rate"
}

cmd_list() {
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "No log file found: $LOG_FILE"
    return 0
  fi

  # Collect stats per run_id
  declare -A run_total run_keep run_discard run_crash run_date

  while IFS= read -r line; do
    [[ "$line" == "run_id	"* ]] && continue
    local f_run_id f_status f_ts
    f_run_id=$(tsv_field "$line" 1)
    f_status=$(tsv_field "$line" 3)
    f_ts=$(tsv_field "$line" 10)

    local date_part="${f_ts:0:10}"
    run_total["$f_run_id"]=$(( ${run_total["$f_run_id"]:-0} + 1 ))
    run_date["$f_run_id"]="${run_date["$f_run_id"]:-$date_part}"
    case "$f_status" in
      keep)    run_keep["$f_run_id"]=$(( ${run_keep["$f_run_id"]:-0} + 1 )) ;;
      discard) run_discard["$f_run_id"]=$(( ${run_discard["$f_run_id"]:-0} + 1 )) ;;
      crash)   run_crash["$f_run_id"]=$(( ${run_crash["$f_run_id"]:-0} + 1 )) ;;
    esac
  done < "$LOG_FILE"

  printf '%-30s  %-12s  %5s  %5s  %7s  %5s\n' "run_id" "date" "total" "keep" "discard" "crash"
  printf '%-30s  %-12s  %5s  %5s  %7s  %5s\n' \
    "------------------------------" "------------" "-----" "-----" "-------" "-----"
  for rid in "${!run_total[@]}"; do
    printf '%-30s  %-12s  %5d  %5d  %7d  %5d\n' \
      "$rid" \
      "${run_date[$rid]:-}" \
      "${run_total[$rid]:-0}" \
      "${run_keep[$rid]:-0}" \
      "${run_discard[$rid]:-0}" \
      "${run_crash[$rid]:-0}"
  done
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
cmd="${1:-help}"; shift || true
case "$cmd" in
  start)   cmd_start   "$@" ;;
  keep)    cmd_keep    "$@" ;;
  discard) cmd_discard "$@" ;;
  crash)   cmd_crash   "$@" ;;
  summary) cmd_summary "$@" ;;
  list)    cmd_list    "$@" ;;
  help|*)  usage ;;
esac
