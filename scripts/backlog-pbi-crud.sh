#!/usr/bin/env bash
# backlog-pbi-crud.sh — Create, read, update, archive PBIs in local backlog
# Usage: ./scripts/backlog-pbi-crud.sh <create|read|update|archive|list> [options]
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail
cat /dev/stdin > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
TEMPLATES="${ROOT}/.claude/templates/backlog"

find_backlog() {
  local project="${1:-}"
  local path=""
  if [ -n "$project" ]; then
    path="${ROOT}/projects/${project}/backlog"
  else
    for p in "${ROOT}"/projects/*/backlog; do
      [ -d "$p" ] && path="$p" && break
    done
  fi
  [ -d "$path" ] && echo "$path" || { echo "Error: No backlog found" >&2; exit 1; }
}

next_id() {
  local config="$1/_config.yaml"
  local counter
  counter=$(grep 'id_counter:' "$config" 2>/dev/null | grep -oP '\d+' || echo "0")
  counter=$((counter + 1))
  sed -i "s/id_counter:.*/id_counter: ${counter}/" "$config"
  printf "%03d" "$counter"
}

cmd_create() {
  local project="" title="" type="User Story" priority="3-Medium"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      --title) title="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --priority) priority="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$title" ] && { echo "Error: --title required" >&2; exit 1; }

  local backlog; backlog=$(find_backlog "$project")
  local id; id=$(next_id "$backlog")
  local slug; slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 40)
  local date; date=$(date +%Y-%m-%d)
  local file="${backlog}/pbi/PBI-${id}-${slug}.md"

  sed -e "s/{ID}/${id}/g" -e "s/{TITLE}/${title}/g" \
      -e "s/{DATE}/${date}/g" -e "s/{DESCRIPTION}/TBD/g" \
      "$TEMPLATES/pbi-template.md" > "$file"
  # Set type and priority
  sed -i "s/type: User Story/type: ${type}/" "$file"
  sed -i "s/priority: 3-Medium/priority: ${priority}/" "$file"

  echo "Created: PBI-${id} — ${title}"
  echo "File: ${file}"
}

cmd_list() {
  local project=""
  while [[ $# -gt 0 ]]; do
    case "$1" in --project) project="$2"; shift 2 ;; *) shift ;; esac
  done
  local backlog; backlog=$(find_backlog "$project")
  echo "| ID | Title | State | Priority | Sprint |"
  echo "|----|-------|-------|----------|--------|"
  for f in "$backlog"/pbi/PBI-*.md; do
    [ -f "$f" ] || continue
    local id title state priority sprint
    id=$(grep '^id:' "$f" | head -1 | sed 's/id: *//')
    title=$(grep '^title:' "$f" | head -1 | sed 's/title: *"//;s/"$//')
    state=$(grep '^state:' "$f" | head -1 | sed 's/state: *//')
    priority=$(grep '^priority:' "$f" | head -1 | sed 's/priority: *//')
    sprint=$(grep '^sprint:' "$f" | head -1 | sed 's/sprint: *"//;s/"$//')
    echo "| $id | $title | $state | $priority | $sprint |"
  done
}

cmd_read() {
  local pbi_id="${1:-}" project=""
  shift 2>/dev/null || true
  while [[ $# -gt 0 ]]; do
    case "$1" in --project) project="$2"; shift 2 ;; *) shift ;; esac
  done
  [ -z "$pbi_id" ] && { echo "Error: PBI ID required" >&2; exit 1; }
  local backlog; backlog=$(find_backlog "$project")
  local file; file=$(find "$backlog/pbi" -name "PBI-${pbi_id}*" 2>/dev/null | head -1)
  [ -z "$file" ] && { echo "Error: PBI-${pbi_id} not found" >&2; exit 1; }
  cat "$file"
}

cmd_update() {
  local pbi_id="" field="" value="" project=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) pbi_id="$2"; shift 2 ;;
      --field) field="$2"; shift 2 ;;
      --value) value="$2"; shift 2 ;;
      --project) project="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$pbi_id" ] || [ -z "$field" ] || [ -z "$value" ] && \
    { echo "Error: --id, --field, --value required" >&2; exit 1; }
  local backlog; backlog=$(find_backlog "$project")
  local file; file=$(find "$backlog/pbi" -name "PBI-${pbi_id}*" 2>/dev/null | head -1)
  [ -z "$file" ] && { echo "Error: PBI-${pbi_id} not found" >&2; exit 1; }
  sed -i "s/^${field}:.*/${field}: ${value}/" "$file"
  sed -i "s/^updated:.*/updated: $(date +%Y-%m-%d)/" "$file"
  echo "Updated PBI-${pbi_id}: ${field} = ${value}"
}

cmd_archive() {
  local pbi_id="" project=""
  while [[ $# -gt 0 ]]; do
    case "$1" in --id) pbi_id="$2"; shift 2 ;; --project) project="$2"; shift 2 ;; *) shift ;; esac
  done
  [ -z "$pbi_id" ] && { echo "Error: --id required" >&2; exit 1; }
  local backlog; backlog=$(find_backlog "$project")
  local file; file=$(find "$backlog/pbi" -name "PBI-${pbi_id}*" 2>/dev/null | head -1)
  [ -z "$file" ] && { echo "Error: PBI-${pbi_id} not found" >&2; exit 1; }
  mkdir -p "$backlog/archive"
  mv "$file" "$backlog/archive/"
  echo "Archived: PBI-${pbi_id} → archive/"
}

case "${1:-help}" in
  create) shift; cmd_create "$@" ;;
  list) shift; cmd_list "$@" ;;
  read) shift; cmd_read "$@" ;;
  update) shift; cmd_update "$@" ;;
  archive) shift; cmd_archive "$@" ;;
  *) echo "Usage: $0 <create|list|read|update|archive> [options]" >&2; exit 1 ;;
esac
