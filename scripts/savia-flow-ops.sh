#!/bin/bash
# savia-flow-ops.sh — CRUD operations for PBIs and assignments
# Sourced by savia-flow.sh — do NOT run directly.

# ── Create PBI ──────────────────────────────────────────────────────
do_create_pbi() {
  local project="${1:?Uso: savia-flow.sh create-pbi <project> <title> <desc> [priority] [estimate]}"
  local title="${2:?Falta title}"
  local description="${3:?Falta description}"
  local priority="${4:-medium}"
  local estimate="${5:-0}"

  local repo_dir handle
  repo_dir=$(get_repo)
  handle=$(get_handle)
  validate_project "$repo_dir" "$project"

  local backlog="$repo_dir/projects/$project/backlog"
  mkdir -p "$backlog/archive"

  # Auto-increment ID from existing files
  local max_id=0
  for f in "$backlog"/pbi-*.md; do
    [ -f "$f" ] || continue
    local num
    num=$(basename "$f" .md | sed 's/pbi-//' | sed 's/^0*//')
    [ -n "$num" ] && [ "$num" -gt "$max_id" ] 2>/dev/null && max_id="$num"
  done
  local next_id=$((max_id + 1))
  local pbi_id; pbi_id=$(printf "PBI-%03d" "$next_id")
  local filename; filename=$(printf "pbi-%03d.md" "$next_id")

  cat > "$backlog/$filename" <<EOF
---
id: "${pbi_id}"
title: "${title}"
status: "new"
priority: "${priority}"
estimate: ${estimate}
assignee: ""
created_by: "${handle}"
created_date: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
sprint: ""
tags: []
---

${description}
EOF

  log_ok "Created $pbi_id: $title"
  echo "  File: projects/$project/backlog/$filename"
}

# ── Assign PBI ──────────────────────────────────────────────────────
do_assign() {
  local project="${1:?Uso: savia-flow.sh assign <project> <pbi_id> <handle>}"
  local pbi_id="${2:?Falta pbi_id}"
  local target_handle="${3:?Falta handle}"

  local repo_dir; repo_dir=$(get_repo)
  validate_project "$repo_dir" "$project"

  local pbi_file
  pbi_file=$(find "$repo_dir/projects/$project/backlog" -name "*.md" \
    -not -path "*/archive/*" | xargs grep -l "id: \"$pbi_id\"" 2>/dev/null | head -1)

  if [ -z "$pbi_file" ]; then
    log_error "PBI $pbi_id not found in $project backlog"
    return 1
  fi

  portable_sed_i "s/^assignee: .*/assignee: \"${target_handle}\"/" "$pbi_file"

  local assigned_dir="$repo_dir/users/$target_handle/flow/assigned"
  mkdir -p "$assigned_dir"
  sed -n '/^---$/,/^---$/p' "$pbi_file" > "$assigned_dir/${pbi_id}.md"

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

  local repo_dir; repo_dir=$(get_repo)
  validate_project "$repo_dir" "$project"

  local backlog="$repo_dir/projects/$project/backlog"
  local pbi_file
  pbi_file=$(find "$backlog" -name "*.md" -not -path "*/archive/*" \
    | xargs grep -l "id: \"$pbi_id\"" 2>/dev/null | head -1)

  if [ -z "$pbi_file" ]; then
    log_error "PBI $pbi_id not found"
    return 1
  fi

  portable_sed_i "s/^status: .*/status: \"${new_status}\"/" "$pbi_file"

  if [ "$new_status" = "done" ]; then
    mkdir -p "$backlog/archive"
    mv "$pbi_file" "$backlog/archive/"
    log_ok "$pbi_id moved to done (archived)"
  else
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

  local ts_dir="$repo_dir/users/$handle/flow/timesheet"
  mkdir -p "$ts_dir"
  local month_file="$ts_dir/$(date +%Y-%m).md"
  local today; today=$(date +%Y-%m-%d)

  if [ ! -f "$month_file" ]; then
    echo "# Timesheet — @$handle — $(date +%Y-%m)" > "$month_file"
    echo "" >> "$month_file"
  fi

  echo "## $today" >> "$month_file"
  echo "- pbi: \"$pbi_id\"" >> "$month_file"
  echo "  hours: $hours" >> "$month_file"
  echo "  project: \"$project\"" >> "$month_file"
  echo "  description: \"$desc\"" >> "$month_file"
  echo "" >> "$month_file"

  log_ok "Logged ${hours}h on $pbi_id ($project)"
}
