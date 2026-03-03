#!/bin/bash
set -euo pipefail

FLOW_DATA_DIR="${FLOW_DATA_DIR:-./.savia-flow-data}"
TIMESHEETS_DIR="${FLOW_DATA_DIR}/timesheets"

timesheet_log() {
    local handle=$1 task_id=$2 hours=$3 notes=${4:-}
    [[ -n "$handle" && -n "$task_id" && -n "$hours" ]] || {
        echo "❌ Usage: timesheet_log <@handle> <task_id> <hours> [notes]"
        return 1
    }
    local yearmonth=$(date +%Y-%m)
    local ts_dir="${TIMESHEETS_DIR}/${handle}/${yearmonth}"
    mkdir -p "$ts_dir"
    local date=$(date +%Y-%m-%d)
    local time=$(date +%H:%M)
    printf "%s %s | %s | %s h | %s\n" "$date" "$time" "$task_id" "$hours" "$notes" >> "${ts_dir}/entries.log"
    echo "✅ Logged $hours h for $task_id by $handle"
}

timesheet_day() {
    local handle=$1 date=${2:-$(date +%Y-%m-%d)}
    [[ -n "$handle" ]] || { echo "❌ Usage: timesheet_day <@handle> [date]"; return 1; }
    local yearmonth=$(echo "$date" | cut -d'-' -f1-2)
    local ts_file="${TIMESHEETS_DIR}/${handle}/${yearmonth}/entries.log"
    [[ -f "$ts_file" ]] || { echo "❌ No timesheet for $handle"; return 1; }
    echo "📋 Timesheet for $handle on $date"
    grep "^$date" "$ts_file" | awk -F'|' '{print $1, $2, $3}' | column -t
    grep "^$date" "$ts_file" | awk -F'|' '{print $2}' | awk '{sum+=$1} END {print "Total:", sum, "h"}'
}

timesheet_report() {
    local handle=$1 from=$2 to=$3
    [[ -n "$handle" && -n "$from" && -n "$to" ]] || {
        echo "❌ Usage: timesheet_report <@handle> <from_date> <to_date>"
        return 1
    }
    echo "📊 Timesheet Report: $handle ($from to $to)"
    find "${TIMESHEETS_DIR}/${handle}" -name "entries.log" -type f 2>/dev/null | while read f; do
        awk -F'|' -v from="$from" -v to="$to" '
            $1 >= from && $1 <= to { sum += $2; items++ }
            END { if (items > 0) print "  Total:", sum, "h", "(", items, "entries )" }
        ' "$f"
    done
}

timesheet_summary() {
    local sprint_id=$1
    [[ -n "$sprint_id" ]] || { echo "❌ Usage: timesheet_summary <sprint_id>"; return 1; }
    echo "⏱️  Sprint Time Summary: $sprint_id"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    find "${TIMESHEETS_DIR}" -name "entries.log" -type f 2>/dev/null | while read f; do
        local total=$(awk -F'|' '{sum+=$2} END {print sum+0}' "$f")
        [[ $total -gt 0 ]] && echo "  $(basename $(dirname "$f")): $total h"
    done
}

case "${1:-help}" in
    log) shift; timesheet_log "$@" ;;
    day) shift; timesheet_day "$@" ;;
    report) shift; timesheet_report "$@" ;;
    summary) shift; timesheet_summary "$@" ;;
    *) echo "Usage: savia-flow-timesheet.sh <log|day|report|summary>" ;;
esac
