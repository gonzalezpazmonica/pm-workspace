#!/bin/bash
# savia-flow-board.sh — ASCII Kanban board renderer via branch isolation
# Sourced by savia-flow.sh — do NOT run directly.
set -euo pipefail

# ── Board: ASCII Kanban ─────────────────────────────────────────────
do_board() {
  local project="${1:?Uso: savia-flow.sh board <project>}"
  local repo_dir team
  repo_dir=$(get_repo)
  team=$(get_team)
  validate_project "$repo_dir" "$project"

  # Collect PBIs by status
  local new_items="" ready_items="" inprog_items="" review_items="" done_items=""
  local new_c=0 ready_c=0 inprog_c=0 review_c=0 done_c=0

  local pbi_list; pbi_list=$(do_list "$repo_dir" "team/$team" "projects/$project/backlog") || echo ""
  echo "$pbi_list" | while read -r f; do
    [ -z "$f" ] && continue
    local content; content=$(do_read "$repo_dir" "team/$team" "projects/$project/backlog/$f") || continue
    local pbi_id title assignee status
    pbi_id=$(echo "$content" | grep "^id:" | cut -d: -f2 | xargs)
    title=$(echo "$content" | grep "^title:" | cut -d: -f2- | xargs)
    assignee=$(echo "$content" | grep "^assignee:" | cut -d: -f2 | xargs)
    status=$(echo "$content" | grep "^status:" | cut -d: -f2 | xargs)

    [ ${#title} -gt 20 ] && title="${title:0:17}..."
    local card="$pbi_id $title"
    [ -n "$assignee" ] && card="$card @$assignee"

    case "$status" in
      new)         new_items+="$card|"; new_c=$((new_c + 1)) ;;
      ready)       ready_items+="$card|"; ready_c=$((ready_c + 1)) ;;
      in-progress) inprog_items+="$card|"; inprog_c=$((inprog_c + 1)) ;;
      review)      review_items+="$card|"; review_c=$((review_c + 1)) ;;
      done)        done_items+="$card|"; done_c=$((done_c + 1)) ;;
    esac
  done

  [ -z "$new_items" ] && [ -z "$ready_items" ] && [ -z "$inprog_items" ] && \
    [ -z "$review_items" ] && [ -z "$done_items" ] && echo "📊 Board: $project (empty)" && return 0

  # Render board
  local col_w=30
  local sep
  sep=$(printf '%0.s-' $(seq 1 $((col_w * 5 + 6))))

  echo ""
  echo -e "${CYAN}=== Kanban Board: $project ===${NC}"
  echo "$sep"
  printf "| %-${col_w}s| %-${col_w}s| %-${col_w}s| %-${col_w}s| %-${col_w}s|\n" \
    "NEW ($new_c)" "READY ($ready_c)" "IN PROGRESS ($inprog_c)" "REVIEW ($review_c)" "DONE ($done_c)"
  echo "$sep"

  # Find max rows
  local max_rows=$new_c
  [ $ready_c -gt $max_rows ] && max_rows=$ready_c
  [ $inprog_c -gt $max_rows ] && max_rows=$inprog_c
  [ $review_c -gt $max_rows ] && max_rows=$review_c
  [ $done_c -gt $max_rows ] && max_rows=$done_c
  [ $max_rows -eq 0 ] && max_rows=1

  # Render rows
  local IFS='|'
  local -a new_a=($new_items) ready_a=($ready_items) inprog_a=($inprog_items)
  local -a review_a=($review_items) done_a=($done_items)
  IFS=' '

  local i
  for ((i=0; i<max_rows; i++)); do
    local c1="${new_a[$i]:-}" c2="${ready_a[$i]:-}" c3="${inprog_a[$i]:-}"
    local c4="${review_a[$i]:-}" c5="${done_a[$i]:-}"

    # Truncate cards to column width
    [ ${#c1} -gt $col_w ] && c1="${c1:0:$((col_w-3))}..."
    [ ${#c2} -gt $col_w ] && c2="${c2:0:$((col_w-3))}..."
    [ ${#c3} -gt $col_w ] && c3="${c3:0:$((col_w-3))}..."
    [ ${#c4} -gt $col_w ] && c4="${c4:0:$((col_w-3))}..."
    [ ${#c5} -gt $col_w ] && c5="${c5:0:$((col_w-3))}..."

    printf "| %-${col_w}s| %-${col_w}s| %-${col_w}s| %-${col_w}s| %-${col_w}s|\n" \
      "$c1" "$c2" "$c3" "$c4" "$c5"
  done

  echo "$sep"
  echo ""

  # WIP warning
  local wip_limit=5
  if [ $inprog_c -gt $wip_limit ]; then
    log_warn "WIP limit exceeded: $inprog_c in progress (limit: $wip_limit)"
  fi
}
