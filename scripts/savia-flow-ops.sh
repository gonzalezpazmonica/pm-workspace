#!/bin/bash
# savia-flow-ops.sh — CRUD operations for PBIs and assignments via branch isolation
# Sourced by savia-flow.sh — do NOT run directly.
set -euo pipefail

# ── Create PBI ──────────────────────────────────────────────────────
do_create_pbi() {
  local project="${1:?Uso: savia-flow.sh create-pbi <project> <title> <desc> [priority] [estimate]}"
  local title="${2:?Falta title}"
  local description="${3:?Falta description}"
  local priority="${4:-medium}"
  local estimate="${5:-0}"

  local repo_dir handle team
  repo_dir=$(get_repo)
  handle=$(get_handle)
  team=$(get_team)
  validate_project "$repo_dir" "$project"

  do_ensure_orphan "$repo_dir" "team/$team" "init: team/$team"

  local backlog_list; backlog_list=$(do_list "$repo_dir" "team/$team" "projects/$project/backlog") || echo ""
  local max_id=0
  echo "$backlog_list" | while read -r f; do
    [ -z "$f" ] && continue
    local num; num=$(echo "$f" | sed 's/pbi-//' | sed 's/^0*//' | sed 's/\.md$//')
    [ -n "$num" ] && [ "$num" -gt "$max_id" ] 2>/dev/null && max_id="$num"
  done
  local next_id=$((max_id + 1))
  local pbi_id; pbi_id=$(printf "PBI-%03d" "$next_id")
  local filename; filename=$(printf "pbi-%03d.md" "$next_id")

  local pbi_content="---
id: \"${pbi_id}\"
title: \"${title}\"
status: \"new\"
priority: \"${priority}\"
estimate: ${estimate}
assignee: \"\"
created_by: \"${handle}\"
created_date: \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
sprint: \"\"
tags: []
---

${description}"

  do_write "$repo_dir" "team/$team" "projects/$project/backlog/$filename" "$pbi_content" "[flow: pbi-create] $pbi_id"
  log_ok "Created $pbi_id: $title"
}

# ── Assign PBI ──────────────────────────────────────────────────────
do_assign() {
  local project="${1:?Uso: savia-flow.sh assign <project> <pbi_id> <handle>}"
  local pbi_id="${2:?Falta pbi_id}"
  local target_handle="${3:?Falta handle}"

  local repo_dir team
  repo_dir=$(get_repo)
  team=$(get_team)
  validate_project "$repo_dir" "$project"

  do_ensure_orphan "$repo_dir" "team/$team" "init: team/$team"
  do_ensure_orphan "$repo_dir" "user/$target_handle" "init: user/$target_handle"

  local backlog_list; backlog_list=$(do_list "$repo_dir" "team/$team" "projects/$project/backlog")
  local pbi_file=""
  echo "$backlog_list" | while read -r f; do
    [ -z "$f" ] && continue
    local content; content=$(do_read "$repo_dir" "team/$team" "projects/$project/backlog/$f") || continue
    [ "$(echo "$content" | grep "^id:" | cut -d: -f2 | xargs)" = "$pbi_id" ] && pbi_file="$f" && break
  done

  [ -n "$pbi_file" ] || { log_error "PBI $pbi_id not found"; return 1; }

  local pbi_content; pbi_content=$(do_read "$repo_dir" "team/$team" "projects/$project/backlog/$pbi_file")
  pbi_content=$(echo "$pbi_content" | sed "s/^assignee: .*/assignee: \"${target_handle}\"/")
  do_write "$repo_dir" "team/$team" "projects/$project/backlog/$pbi_file" "$pbi_content" "[flow: assign] $pbi_id → @$target_handle"

  do_write "$repo_dir" "user/$target_handle" "flow/assigned/${pbi_id}.md" "$pbi_content" "[flow: assign-copy] $pbi_id"
  log_ok "$pbi_id assigned to @$target_handle"
}

# ── Move PBI (state machine) ───────────────────────────────────────
do_move() {
  local project="${1:?Uso: savia-flow.sh move <project> <pbi_id> <status>}"
  local pbi_id="${2:?Falta pbi_id}"
  local new_status="${3:?Falta status}"

  case "$new_status" in
    new|ready|in-progress|review|done) ;;
    *) log_error "Invalid status: $new_status. Valid: new|ready|in-progress|review|done"; return 1 ;;
  esac

  local repo_dir team
  repo_dir=$(get_repo)
  team=$(get_team)
  validate_project "$repo_dir" "$project"

  local backlog_list; backlog_list=$(do_list "$repo_dir" "team/$team" "projects/$project/backlog")
  local pbi_file=""
  echo "$backlog_list" | while read -r f; do
    [ -z "$f" ] && continue
    local content; content=$(do_read "$repo_dir" "team/$team" "projects/$project/backlog/$f") || continue
    [ "$(echo "$content" | grep "^id:" | cut -d: -f2 | xargs)" = "$pbi_id" ] && pbi_file="$f" && break
  done

  [ -n "$pbi_file" ] || { log_error "PBI $pbi_id not found"; return 1; }

  local pbi_content; pbi_content=$(do_read "$repo_dir" "team/$team" "projects/$project/backlog/$pbi_file")
  pbi_content=$(echo "$pbi_content" | sed "s/^status: .*/status: \"${new_status}\"/")

  if [ "$new_status" = "done" ]; then
    do_write "$repo_dir" "team/$team" "projects/$project/backlog/archive/$pbi_file" "$pbi_content" "[flow: archive] $pbi_id"
    log_ok "$pbi_id moved to done (archived)"
  else
    do_write "$repo_dir" "team/$team" "projects/$project/backlog/$pbi_file" "$pbi_content" "[flow: move] $pbi_id → $new_status"
    log_ok "$pbi_id moved to $new_status"
  fi
}

# ── Log time ────────────────────────────────────────────────────────
do_log_time() {
  local project="${1:?Uso: savia-flow.sh log-time <project> <pbi_id> <hours> <desc>}"
  local pbi_id="${2:?Falta pbi_id}"
  local hours="${3:?Falta hours}"
  local desc="${4:?Falta description}"

  local repo_dir handle
  repo_dir=$(get_repo)
  handle=$(get_handle)

  do_ensure_orphan "$repo_dir" "user/$handle" "init: user/$handle"

  local month_file="flow/timesheet/$(date +%Y-%m).md"
  local today; today=$(date +%Y-%m-%d)
  local content; content=$(do_read "$repo_dir" "user/$handle" "$month_file") || content="# Timesheet — @$handle — $(date +%Y-%m)"

  content="${content}

## $today
- pbi: \"$pbi_id\"
  hours: $hours
  project: \"$project\"
  description: \"$desc\""

  do_write "$repo_dir" "user/$handle" "$month_file" "$content" "[flow: log-time] $pbi_id: ${hours}h"
  log_ok "Logged ${hours}h on $pbi_id ($project)"
}
