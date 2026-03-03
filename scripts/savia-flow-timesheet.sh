#!/bin/bash
# savia-flow-timesheet.sh — Time tracking via user branch
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-branch.sh"
source "$SCRIPTS_DIR/savia-compat.sh"

CONFIG_DIR="$HOME/.pm-workspace"
CONFIG_FILE="$CONFIG_DIR/company-repo"

read_config() {
  portable_read_config "$1" "$CONFIG_FILE"
}

get_repo() {
  local path; path=$(read_config "LOCAL_PATH")
  [ -z "$path" ] || [ ! -d "$path/.git" ] && { echo ""; return 1; }
  echo "$path"
}

timesheet_log() {
    local repo_dir="${1:?}" handle="${2:?}" task_id="${3:?}" hours="${4:?}" notes="${5:-}"
    local yearmonth=$(date +%Y-%m)
    local ts_path="flow/timesheet/${yearmonth}.md"

    do_ensure_orphan "$repo_dir" "user/$handle" "init: user/$handle"
    local content; content=$(do_read "$repo_dir" "user/$handle" "$ts_path") || content="# Timesheet — @${handle} — ${yearmonth}"

    local date=$(date +%Y-%m-%d)
    local time=$(date +%H:%M)
    content="${content}
${date} ${time} | ${task_id} | ${hours}h | ${notes}"

    do_write "$repo_dir" "user/$handle" "$ts_path" "$content" "[flow: log-time] ${task_id}: ${hours}h"
    echo "✅ Logged $hours h for $task_id by @$handle"
}

timesheet_day() {
    local repo_dir="${1:?}" handle="${2:?}" date="${3:-$(date +%Y-%m-%d)}"
    local yearmonth=$(echo "$date" | cut -d'-' -f1-2)
    local ts_path="flow/timesheet/${yearmonth}.md"
    local content; content=$(do_read "$repo_dir" "user/$handle" "$ts_path") || { echo "❌ No timesheet for @$handle"; return 1; }
    echo "📋 Timesheet for @$handle on $date"
    echo "$content" | grep "^$date" || echo "(no entries for $date)"
}

timesheet_report() {
    local repo_dir="${1:?}" handle="${2:?}" from="${3:?}" to="${4:?}"
    echo "📊 Timesheet Report: @$handle ($from to $to)"
    local yearmonth; yearmonth=$(echo "$from" | cut -d'-' -f1-2)
    local ts_path="flow/timesheet/${yearmonth}.md"
    local content; content=$(do_read "$repo_dir" "user/$handle" "$ts_path") || { echo "  (no data)"; return 0; }
    echo "$content" | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}" | grep -E "^$from|^$to" || echo "  (no entries in range)"
}

case "${1:-help}" in
    log) shift; timesheet_log "$(get_repo)" "$@" ;;
    day) shift; timesheet_day "$(get_repo)" "$@" ;;
    report) shift; timesheet_report "$(get_repo)" "$@" ;;
    *) echo "Usage: savia-flow-timesheet.sh <log|day|report>" ;;
esac
