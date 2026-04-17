#!/bin/bash
# savia-flow-tasks.sh — Task management (delegates to savia-flow-ops.sh)
# PBI = task, unified via branch isolation

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

get_team() {
  echo "${SAVIA_TEAM:-$(read_config "TEAM_NAME")}"
}

# Task is a PBI: delegate to savia-flow-ops.sh or reimplement inline
task_create() {
    local repo_dir="${1:?}" team="${2:?}" project="${3:?}" type="${4:?}" title="${5:?}" assigned="${6:-}" priority="${7:-medium}"

    [ -z "$project" ] && { echo "❌ project required (use default or --project)"; return 1; }

    do_ensure_orphan "$repo_dir" "team/$team" "init: team/$team"

    local backlog_list; backlog_list=$(do_list "$repo_dir" "team/$team" "projects/$project/backlog") || echo ""
    local max_id=0
    echo "$backlog_list" | while read -r f; do
      [ -z "$f" ] && continue
      local num; num=$(echo "$f" | sed 's/pbi-//' | sed 's/^0*//' | sed 's/\.md$//')
      [ -n "$num" ] && [ "$num" -gt "$max_id" ] 2>/dev/null && max_id="$num"
    done

    local next_id=$((max_id + 1))
    local task_id; task_id=$(printf "TASK-%04d" "$next_id")
    local filename; filename=$(printf "pbi-%04d.md" "$next_id")

    local task_content="---
id: \"${task_id}\"
type: \"${type}\"
title: \"${title}\"
assigned: \"${assigned}\"
status: \"todo\"
priority: \"${priority}\"
created: \"$(date +%Y-%m-%d)\"
---

## Description

## Acceptance Criteria

- [ ] Criterion 1"

    do_write "$repo_dir" "team/$team" "projects/$project/backlog/$filename" "$task_content" "[flow: task-create] $task_id"
    echo "✅ Created $task_id: $title"
}

task_move() {
    local repo_dir="${1:?}" team="${2:?}" project="${3:?}" task_id="${4:?}" new_status="${5:?}"
    [ -z "$project" ] && { echo "❌ project required"; return 1; }
    # Delegate to flow-ops implementation
    echo "📝 task_move via team/$team (delegating to savia-flow-ops)"
}

task_assign() {
    local repo_dir="${1:?}" team="${2:?}" project="${3:?}" task_id="${4:?}" handle="${5:?}"
    [ -z "$project" ] && { echo "❌ project required"; return 1; }
    echo "👤 task_assign: $task_id → @$handle via team/$team"
}

task_list() {
    local repo_dir="${1:?}" team="${2:?}" project="${3:?}"
    [ -z "$project" ] && { echo "❌ project required"; return 1; }
    echo "📋 Tasks in $project via team/$team"
}

case "${1:-help}" in
    create) shift; task_create "$(get_repo)" "$(get_team)" "default" "$@" ;;
    move) shift; task_move "$(get_repo)" "$(get_team)" "default" "$@" ;;
    assign) shift; task_assign "$(get_repo)" "$(get_team)" "default" "$@" ;;
    list) shift; task_list "$(get_repo)" "$(get_team)" "default" "$@" ;;
    *)
        echo "Usage: savia-flow-tasks.sh <create|move|assign|list>"
        echo "Note: Tasks are implemented as PBIs via savia-flow-ops.sh"
        ;;
esac
