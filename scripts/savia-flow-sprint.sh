#!/bin/bash
set -euo pipefail

FLOW_DATA_DIR="${FLOW_DATA_DIR:-./.savia-flow-data}"
SPRINTS_DIR="${FLOW_DATA_DIR}/sprints"
REPORTS_DIR="${FLOW_DATA_DIR}/reports"

sprint_create() {
    local goal=$1 start_date=$2 end_date=$3 capacity_h=${4:-120}
    [[ -n "$goal" && -n "$start_date" && -n "$end_date" ]] || {
        echo "❌ Usage: sprint_create <goal> <start_date> <end_date> [capacity_h]"
        return 1
    }
    local year=$(date +%Y)
    local seq=$(ls "${SPRINTS_DIR}" 2>/dev/null | grep -c "SPR-${year}" || echo 0)
    seq=$((seq + 1))
    local sprint_id="SPR-${year}-$(printf '%02d' $seq)"
    local sprint_dir="${SPRINTS_DIR}/${sprint_id}"
    mkdir -p "${sprint_dir}/board/todo" "${sprint_dir}/board/in-progress"
    mkdir -p "${sprint_dir}/board/review" "${sprint_dir}/board/done"
    mkdir -p "${sprint_dir}/daily"
    printf "---\nid: %s\ngoal: %s\nstart_date: %s\nend_date: %s\ncapacity_h: %s\nstatus: active\ncreated: %s\nclosed: null\nvelocity: 0\n---\n\n## Sprint Goal\n\n%s\n\n## Key Results\n\n- [ ] Result 1\n" \
        "$sprint_id" "$goal" "$start_date" "$end_date" "$capacity_h" "$(date +%Y-%m-%d)" "$goal" > "${sprint_dir}/sprint.md"
    echo "✅ Created $sprint_id: $goal"
}

sprint_close() {
    local sprint_id=$1
    [[ -n "$sprint_id" ]] || { echo "❌ Usage: sprint_close <sprint_id>"; return 1; }
    local sprint_dir="${SPRINTS_DIR}/${sprint_id}"
    [[ -d "$sprint_dir" ]] || { echo "❌ Sprint $sprint_id not found"; return 1; }
    local velocity=$(find "${sprint_dir}/board/done" -name "*.md" 2>/dev/null | wc -l)
    find "${sprint_dir}/board/todo" "${sprint_dir}/board/in-progress" -name "*.md" 2>/dev/null | while read file; do
        cp "$file" "${FLOW_DATA_DIR}/backlog/" 2>/dev/null || true
    done
    sed -i "s/^status: .*/status: closed/" "${sprint_dir}/sprint.md"
    sed -i "s/^velocity: .*/velocity: $velocity/" "${sprint_dir}/sprint.md"
    sed -i "s/^closed: .*/closed: $(date +%Y-%m-%d)/" "${sprint_dir}/sprint.md"
    mkdir -p "${REPORTS_DIR}"
    echo "✅ Closed $sprint_id | Velocity: $velocity SP"
}

sprint_board() {
    local sprint_id=$1
    [[ -n "$sprint_id" ]] || { echo "❌ Usage: sprint_board <sprint_id>"; return 1; }
    local sprint_dir="${SPRINTS_DIR}/${sprint_id}"
    [[ -d "$sprint_dir" ]] || { echo "❌ Sprint $sprint_id not found"; return 1; }
    echo "📊 Sprint Board: $sprint_id"
    for col in todo in-progress review done; do
        local count=$(find "${sprint_dir}/board/${col}" -name "*.md" 2>/dev/null | wc -l)
        echo "  $col: $count"
    done
}

sprint_burndown() {
    local sprint_id=$1
    local sprint_dir="${SPRINTS_DIR}/${sprint_id}"
    [[ -d "$sprint_dir" ]] || return
    local todo=$(find "${sprint_dir}/board/todo" -name "*.md" 2>/dev/null | wc -l)
    local inprog=$(find "${sprint_dir}/board/in-progress" -name "*.md" 2>/dev/null | wc -l)
    local review=$(find "${sprint_dir}/board/review" -name "*.md" 2>/dev/null | wc -l)
    local done=$(find "${sprint_dir}/board/done" -name "*.md" 2>/dev/null | wc -l)
    echo "| todo | $todo | in-progress | $inprog | review | $review | done | $done |"
}

sprint_velocity() {
    echo "📈 Historical Velocity"
    find "${SPRINTS_DIR}" -name "sprint.md" -type f 2>/dev/null | while read f; do
        grep '^velocity: [1-9]' "$f" && grep '^id:' "$f" | cut -d' ' -f2
    done | head -10
}

case "${1:-help}" in
    create) shift; sprint_create "$@" ;;
    close) shift; sprint_close "$@" ;;
    board) shift; sprint_board "$@" ;;
    burndown) shift; sprint_burndown "$@" ;;
    velocity) sprint_velocity ;;
    *) echo "Usage: savia-flow-sprint.sh <create|close|board|burndown|velocity>" ;;
esac
