#!/usr/bin/env bash
# backlog-resolver.sh — Resolve backlog data source (local-first, API fallback)
# Sourced by commands that need backlog data. Provides functions to read PBIs,
# sprint info, and board status from local backlog or Azure DevOps.
# Usage: source scripts/backlog-resolver.sh
# ─────────────────────────────────────────────────────────────────
set -uo pipefail

RESOLVER_ROOT="${RESOLVER_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ── Detect backlog source ──
resolve_backlog_path() {
  local project="${1:-}"
  local path=""
  if [ -n "$project" ]; then
    path="${RESOLVER_ROOT}/projects/${project}/backlog"
  else
    for p in "${RESOLVER_ROOT}"/projects/*/backlog; do
      [ -d "$p" ] && path="$p" && break
    done
  fi
  echo "$path"
}

has_local_backlog() {
  local path; path=$(resolve_backlog_path "${1:-}")
  [ -d "$path" ] && [ -f "$path/_config.yaml" ]
}

# ── Get current sprint ID ──
get_current_sprint() {
  local project="${1:-}"
  local backlog; backlog=$(resolve_backlog_path "$project")
  if [ -f "$backlog/_current-sprint.md" ]; then
    cat "$backlog/_current-sprint.md" | tr -d '[:space:]'
  else
    date +%Y-S%V
  fi
}

# ── Count PBIs by state ──
count_by_state() {
  local project="${1:-}" state="${2:-}"
  local backlog; backlog=$(resolve_backlog_path "$project")
  [ ! -d "$backlog/pbi" ] && echo "0" && return
  if [ -n "$state" ]; then
    grep -rl "^state: ${state}" "$backlog/pbi/" 2>/dev/null | grep -c . || echo "0"
  else
    find "$backlog/pbi" -name "PBI-*.md" 2>/dev/null | grep -c . || echo "0"
  fi
}

# ── Board summary (PBIs grouped by state) ──
board_summary() {
  local project="${1:-}"
  local backlog; backlog=$(resolve_backlog_path "$project")
  [ ! -d "$backlog/pbi" ] && echo "No backlog found" && return
  local new active resolved closed
  new=$(count_by_state "$project" "New")
  active=$(count_by_state "$project" "Active")
  resolved=$(count_by_state "$project" "Resolved")
  closed=$(count_by_state "$project" "Closed")
  echo "New: $new | Active: $active | Resolved: $resolved | Closed: $closed"
}

# ── Sprint items (PBIs assigned to current sprint) ──
sprint_items() {
  local project="${1:-}"
  local sprint; sprint=$(get_current_sprint "$project")
  local backlog; backlog=$(resolve_backlog_path "$project")
  [ ! -d "$backlog/pbi" ] && return
  echo "| ID | Title | State | Assigned | SP |"
  echo "|----|-------|-------|----------|----|"
  for f in "$backlog"/pbi/PBI-*.md; do
    [ -f "$f" ] || continue
    local s; s=$(grep '^sprint:' "$f" 2>/dev/null | sed 's/sprint: *"//;s/"$//' | tr -d '[:space:]')
    [ "$s" != "$sprint" ] && continue
    local id title state assigned sp
    id=$(grep '^id:' "$f" | head -1 | sed 's/id: *//')
    title=$(grep '^title:' "$f" | head -1 | sed 's/title: *"//;s/"$//')
    state=$(grep '^state:' "$f" | head -1 | sed 's/state: *//')
    assigned=$(grep '^assigned_to:' "$f" | head -1 | sed 's/assigned_to: *"//;s/"$//')
    sp=$(grep '^estimation_sp:' "$f" | head -1 | sed 's/estimation_sp: *//')
    echo "| $id | $title | $state | ${assigned:-—} | ${sp:-0} |"
  done
}

# ── Data source indicator ──
data_source() {
  local project="${1:-}"
  if has_local_backlog "$project"; then
    echo "local"
  elif [ -n "${AZURE_DEVOPS_ORG_URL:-}" ]; then
    echo "azure-devops"
  else
    echo "none"
  fi
}
