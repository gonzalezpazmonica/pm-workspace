#!/usr/bin/env bash
# criticality-engine.sh — Operations: assess, dashboard, rebalance. Sourced by criticality.sh.
# Exit codes: 0 ok · 1 item/project not found · 2 usage error or ambiguous item.
set -uo pipefail

source "$SCRIPT_DIR/criticality-scoring.sh"
source "$SCRIPT_DIR/criticality-items.sh"

usage_err() { echo "ERROR: $*" >&2; }

# parse_project_opt <args...> — sets OPT_PROJECT and OPT_REST (positional args).
parse_project_opt() {
  OPT_PROJECT="" OPT_REST=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        [[ $# -ge 2 && -n "$2" ]] || { usage_err "--project requires a project name"; return 2; }
        valid_project "$2" || { usage_err "invalid project name: $2"; return 2; }
        OPT_PROJECT="$2"; shift 2 ;;
      --dry-run) shift ;;
      -*) usage_err "unknown option: $1"; return 2 ;;
      *) OPT_REST+=("$1"); shift ;;
    esac
  done
}

# ── Assess single item ───────────────────────────────────────────────────────
do_assess() {
  parse_project_opt "$@" || return 2
  local item_id="${OPT_REST[0]:-}" project="$OPT_PROJECT"
  if [[ -z "$item_id" || ${#OPT_REST[@]} -gt 1 ]]; then
    echo "Usage: criticality.sh assess <item-id> [--project name]" >&2; return 2
  fi
  valid_item_id "$item_id" || { usage_err "invalid item id: $item_id"; return 2; }
  if [[ -n "$project" && ! -d "$WORKSPACE_ROOT/projects/$project/backlog" ]]; then
    echo "Project $project has no local backlog." >&2; return 1
  fi

  local matches; matches=$(find_item "$item_id" "$project")
  [[ -z "$matches" ]] && { echo "Item $item_id not found in local backlog." >&2; return 1; }
  if [[ "$matches" == *$'\n'* ]]; then
    echo "Item $item_id is ambiguous; use --project or a full id:" >&2
    local m; while IFS= read -r m; do echo "  ${m#"$WORKSPACE_ROOT"/}" >&2; done <<< "$matches"
    return 2
  fi

  local f="$matches" title state assigned
  title=$(parse_frontmatter "$f" title); [[ -z "$title" ]] && title="$(basename "$f" .md)"
  state=$(fm_first "$f" state status)
  assigned=$(parse_frontmatter "$f" assigned_to)
  local score impact urg deps c10 ei sp days cpct
  read -r score impact urg deps c10 ei sp days cpct <<< "$(item_metrics "$f")"

  echo "Assessment: $item_id — $title"
  echo "  State: ${state:-unknown} | SP: $sp | Assigned: ${assigned:-unassigned}"
  echo ""
  echo "  Impact       $(bar5 "$impact") $impact/5  x0.30"
  echo "  Urgency      $(bar5 "$urg") $urg/5  x0.25  (${days}d)"
  echo "  Dependencies $(bar5 "$deps") $deps/5  x0.20"
  echo "  Confidence   $(bar5 $((c10 / 10))) $((c10 / 10)).$((c10 % 10))/5  x0.15  (decay: ${cpct}%)"
  echo "  Effort inv   $(bar5 "$ei") $ei/5  x0.10"
  echo "  ─────────────────────"
  echo "  Score: $(score_display "$score") → $(classify "$score")"
}

# ── Dashboard ─────────────────────────────────────────────────────────────────
do_dashboard() {
  parse_project_opt "$@" || return 2
  local project="$OPT_PROJECT" items
  if ! items=$(scan_items "$project"); then
    echo "Project $project has no local backlog." >&2; return 1
  fi
  [[ -z "$items" ]] && { echo "No items in local backlog."; return 0; }

  local rows="" f title assigned score
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    is_active "$f" || continue
    title=$(parse_frontmatter "$f" title); [[ -z "$title" ]] && title="$(basename "$f" .md)"
    assigned=$(parse_frontmatter "$f" assigned_to); [[ -z "$assigned" ]] && assigned="?"
    read -r score _ <<< "$(item_metrics "$f")"
    rows+="$score"$'\t'"${title//$'\t'/ }"$'\t'"${assigned//$'\t'/ }"$'\n'
  done <<< "$items"

  local p0=() p1=() n2=0 n3=0 alerts=() line s t a
  while IFS=$'\t' read -r s t a; do
    [[ -z "$s" ]] && continue
    line="  $(score_display "$s") | $t | $a"
    case "$(classify "$s")" in
      "P0 Critical") p0+=("$line"); [[ "$a" == "?" ]] && alerts+=("  ALERT: P0 unassigned — $t") ;;
      "P1 High")     p1+=("$line") ;;
      "P2 Medium")   n2=$((n2 + 1)) ;;
      *)             n3=$((n3 + 1)) ;;
    esac
  done < <(printf '%s' "$rows" | LC_ALL=C sort -t$'\t' -k1,1nr -s)

  echo "Criticality Dashboard — $(today_ymd)"
  echo ""
  echo "P0 Critical (${#p0[@]})"
  (( ${#p0[@]} )) && printf '%s\n' "${p0[@]}"
  echo "P1 High (${#p1[@]})"
  (( ${#p1[@]} )) && printf '%s\n' "${p1[@]}"
  echo "P2 Medium ($n2)"
  echo "P3 Low ($n3)"

  (( ${#p0[@]} > 3 )) && alerts+=("  ALERT: ${#p0[@]} P0 items — capacity critical")
  echo ""
  if (( ${#alerts[@]} )); then printf '%s\n' "${alerts[@]}"; else echo "No alerts."; fi
}

# ── Rebalance ─────────────────────────────────────────────────────────────────
do_rebalance() {
  parse_project_opt "$@" || return 2
  echo "Analyzing current assignments..."
  do_dashboard ${OPT_PROJECT:+--project "$OPT_PROJECT"} || return $?
  echo ""
  echo "Interactive rebalancing requires /criticality-rebalance in Claude Code."
}
