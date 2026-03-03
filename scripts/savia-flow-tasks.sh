#!/bin/bash
# savia-flow-tasks.sh — Git-native task management for Savia Flow
# Manages tasks, subtasks, bugs, spikes with filesystem state

set -euo pipefail

FLOW_DATA_DIR="${FLOW_DATA_DIR:-./.savia-flow-data}"
BACKLOG_DIR="${FLOW_DATA_DIR}/backlog"
SPRINTS_DIR="${FLOW_DATA_DIR}/sprints"

# Task ID generation: TASK-YYYY-NNNN
task_create() {
    local type=$1 title=$2 assigned=$3 sprint=$4 priority=${5:-medium}

    [[ -n "$type" && -n "$title" ]] || {
        echo "❌ Usage: task_create <type> <title> <@assigned> <sprint> [priority]"
        return 1
    }

    # Generate ID
    local year=$(date +%Y)
    local seq=$(ls "${BACKLOG_DIR:-.}" 2>/dev/null | grep -c "TASK-${year}" || echo 0)
    seq=$((seq + 1))
    local task_id="TASK-${year}-$(printf '%04d' $seq)"

    # Create task file
    local task_file="${BACKLOG_DIR}/${task_id}.md"
    mkdir -p "${BACKLOG_DIR}"

    cat > "$task_file" <<EOF
---
id: $task_id
type: $type
parent:
title: $title
assigned: $assigned
status: todo
priority: $priority
estimate_h: 0
spent_h: 0
sprint: $sprint
tags: []
created: $(date +%Y-%m-%d)
updated: $(date +%Y-%m-%d)
---

## Description

## Acceptance Criteria

- [ ] Criterion 1

## Comments

EOF

    echo "✅ Created $task_id: $title"
}

task_move() {
    local task_id=$1 new_status=$2

    [[ -n "$task_id" && -n "$new_status" ]] || {
        echo "❌ Usage: task_move <task_id> <status>"
        return 1
    }

    # Find task file
    local task_file=$(find "${SPRINTS_DIR}" "${BACKLOG_DIR}" -name "${task_id}.md" 2>/dev/null | head -1)
    [[ -f "$task_file" ]] || {
        echo "❌ Task $task_id not found"
        return 1
    }

    # Update status in frontmatter
    sed -i "s/^status: .*/status: $new_status/" "$task_file"
    sed -i "s/^updated: .*/updated: $(date +%Y-%m-%d)/" "$task_file"

    # Move file if sprint-based board columns exist
    local sprint=$(grep '^sprint:' "$task_file" | cut -d' ' -f2)
    if [[ -n "$sprint" ]]; then
        local board_dir="${SPRINTS_DIR}/${sprint}/board"
        mkdir -p "${board_dir}/{todo,in-progress,review,done}"
        local new_path="${board_dir}/${new_status}/${task_id}.md"
        mv "$task_file" "$new_path" 2>/dev/null || true
    fi

    echo "✅ Moved $task_id to $new_status"
}

task_assign() {
    local task_id=$1 handle=$2

    [[ -n "$task_id" && -n "$handle" ]] || {
        echo "❌ Usage: task_assign <task_id> <@handle>"
        return 1
    }

    local task_file=$(find "${SPRINTS_DIR}" "${BACKLOG_DIR}" -name "${task_id}.md" 2>/dev/null | head -1)
    [[ -f "$task_file" ]] || {
        echo "❌ Task $task_id not found"
        return 1
    }

    sed -i "s/^assigned: .*/assigned: $handle/" "$task_file"
    echo "✅ Assigned $task_id to $handle"
}

task_list() {
    local sprint=$1 status=${2:-}

    local search_dir="${SPRINTS_DIR}/${sprint}/board" || search_dir="${BACKLOG_DIR}"
    [[ -d "$search_dir" ]] || {
        echo "❌ Sprint $sprint not found"
        return 1
    }

    echo "📋 Tasks in $sprint${status:+ ($status)}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ -n "$status" ]]; then
        find "${search_dir}/${status}" -name "*.md" 2>/dev/null | while read file; do
            grep '^id:' "$file" | cut -d' ' -f2
            grep '^title:' "$file" | cut -d' ' -f2-
            echo "  assigned: $(grep '^assigned:' "$file" | cut -d' ' -f2)"
            echo
        done
    else
        for col in todo in-progress review done; do
            [[ -d "${search_dir}/${col}" ]] && {
                echo "### $col"
                find "${search_dir}/${col}" -name "*.md" 2>/dev/null | wc -l | xargs echo "  Count:"
            }
        done
    fi
}

task_show() {
    local task_id=$1

    [[ -n "$task_id" ]] || {
        echo "❌ Usage: task_show <task_id>"
        return 1
    }

    local task_file=$(find "${SPRINTS_DIR}" "${BACKLOG_DIR}" -name "${task_id}.md" 2>/dev/null | head -1)
    [[ -f "$task_file" ]] || {
        echo "❌ Task $task_id not found"
        return 1
    }

    cat "$task_file"
}

# Main dispatcher
case "${1:-help}" in
    create) shift; task_create "$@" ;;
    move) shift; task_move "$@" ;;
    assign) shift; task_assign "$@" ;;
    list) shift; task_list "$@" ;;
    show) shift; task_show "$@" ;;
    *)
        echo "Usage: savia-flow-tasks.sh <create|move|assign|list|show>"
        ;;
esac
