#!/usr/bin/env bash
# criticality-engine.sh — Operations: assess, dashboard, rebalance. Sourced by criticality.sh.
set -uo pipefail

source "$SCRIPT_DIR/criticality-scoring.sh"

# ── Assess single item ───────────────────────────────────────────────────────
do_assess() {
  local item_id="${1:-}"
  [[ -z "$item_id" ]] && { echo "Usage: criticality.sh assess <item-id> [--project name]"; return 1; }
  local project=""
  [[ "${2:-}" == "--project" ]] && project="${3:-}"

  local item_file=""
  if [[ -n "$project" ]]; then
    item_file=$(find "$WORKSPACE_ROOT/projects/$project/backlog" -name "*${item_id}*" -print -quit 2>/dev/null)
  else
    item_file=$(find "$WORKSPACE_ROOT/projects/*/backlog" -name "*${item_id}*" -print -quit 2>/dev/null)
  fi
  [[ -z "$item_file" || ! -f "$item_file" ]] && { echo "Item $item_id not found in local backlog."; return 1; }

  local title; title=$(parse_frontmatter "$item_file" "title")
  [[ -z "$title" ]] && title="$(basename "$item_file" .md)"
  local state; state=$(parse_frontmatter "$item_file" "status")
  local sp; sp=$(parse_frontmatter "$item_file" "story_points"); [[ -z "$sp" ]] && sp=3
  local assigned; assigned=$(parse_frontmatter "$item_file" "assigned_to")
  local impact; impact=$(parse_frontmatter "$item_file" "impact"); [[ -z "$impact" ]] && impact=3
  local deps; deps=$(parse_frontmatter "$item_file" "dependencies"); [[ -z "$deps" ]] && deps=1
  local deadline; deadline=$(parse_frontmatter "$item_file" "deadline")

  local days_left=999
  [[ -n "$deadline" ]] && days_left=$(days_between "$(today_epoch)" "$(date_epoch "$deadline")")
  local urgency; urgency=$(urgency_boost "$days_left" 3)
  local cpct; cpct=$(confidence_decay "$(file_age_days "$item_file")")
  local conf_dim=$(( 5 * cpct / 100 )); (( conf_dim < 1 )) && conf_dim=1
  local eff_inv; eff_inv=$(effort_inverse "$sp")
  local score; score=$(compute_score "$impact" "$urgency" "$deps" "$cpct" "$sp")
  local class; class=$(classify "$score")

  echo "Assessment: $item_id — $title"
  echo "  State: ${state:-unknown} | SP: $sp | Assigned: ${assigned:-unassigned}"
  echo ""
  echo "  Impact       $(bar5 "$impact") $impact/5  x0.30"
  echo "  Urgency      $(bar5 "$urgency") $urgency/5  x0.25  (${days_left}d)"
  echo "  Dependencies $(bar5 "$deps") $deps/5  x0.20"
  echo "  Confidence   $(bar5 "$conf_dim") $conf_dim/5  x0.15  (decay: ${cpct}%)"
  echo "  Effort inv   $(bar5 "$eff_inv") $eff_inv/5  x0.10"
  echo "  ─────────────────────"
  echo "  Score: $(score_display "$score") → $class"
}

# ── Dashboard ─────────────────────────────────────────────────────────────────
do_dashboard() {
  local project=""
  [[ "${1:-}" == "--project" ]] && project="${2:-}"

  local items; items=$(scan_items "$project")
  [[ -z "$items" ]] && { echo "No items in local backlog."; return 0; }

  local p0=0 p1=0 p2=0 p3=0 p0_lines="" p1_lines="" alerts=""
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    local title; title=$(parse_frontmatter "$f" "title")
    [[ -z "$title" ]] && title="$(basename "$f" .md)"
    local assigned; assigned=$(parse_frontmatter "$f" "assigned_to"); [[ -z "$assigned" ]] && assigned="?"
    local score; score=$(score_item "$f")
    local cls; cls=$(classify "$score")
    local line="  $(score_display "$score") | $title | $assigned"
    case "$cls" in
      "P0 Critical") p0=$((p0+1)); p0_lines+="$line\n"
        [[ "$assigned" == "?" ]] && alerts+="  ALERT: P0 unassigned — $title\n" ;;
      "P1 High")     p1=$((p1+1)); p1_lines+="$line\n" ;;
      "P2 Medium")   p2=$((p2+1)) ;;
      *)             p3=$((p3+1)) ;;
    esac
  done <<< "$items"

  echo "Criticality Dashboard — $(date +%Y-%m-%d)"
  echo ""
  echo "P0 Critical ($p0)"
  [[ -n "$p0_lines" ]] && printf "%b" "$p0_lines"
  echo "P1 High ($p1)"
  [[ -n "$p1_lines" ]] && printf "%b" "$p1_lines"
  echo "P2 Medium ($p2)"
  echo "P3 Low ($p3)"

  (( p0 > 3 )) && alerts+="  ALERT: $p0 P0 items — capacity critical\n"
  if [[ -n "$alerts" ]]; then
    echo ""; printf "%b" "$alerts"
  else
    echo ""; echo "No alerts."
  fi
}

# ── Rebalance ─────────────────────────────────────────────────────────────────
do_rebalance() {
  local project=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      --dry-run) shift ;;
      *) shift ;;
    esac
  done
  echo "Analyzing current assignments..."
  do_dashboard ${project:+--project "$project"}
  echo ""
  echo "Interactive rebalancing requires /criticality-rebalance in Claude Code."
}
