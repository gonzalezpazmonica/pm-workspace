#!/usr/bin/env bash
# criticality-engine.sh — Local backlog access (frontmatter, dates, item lookup,
# per-item metrics) and operations: assess, dashboard, rebalance.
# Sourced by criticality.sh (needs WORKSPACE_ROOT); scoring lives in criticality-scoring.sh.
# Accepts the local PBI template (id/state/estimation_sp) and the legacy keys
# (status/story_points). Items under backlog/**/archive/ are ignored.
# Exit codes: 0 ok · 1 item/project not found · 2 usage error or ambiguous item.
set -uo pipefail

source "$SCRIPT_DIR/criticality-scoring.sh"

# ── Backlog access ───────────────────────────────────────────────────────────
# parse_frontmatter <file> <key> — value of <key> in the leading --- block only.
# Strips CR, surrounding quotes and unquoted trailing "# comments".
parse_frontmatter() {
  awk -v k="$2" '
    { sub(/\r$/, "") }
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      f = substr(v, 1, 1); l = substr(v, length(v), 1)
      if (length(v) >= 2 && (f == "\"" || f == "\047") && l == f) v = substr(v, 2, length(v) - 2)
      else sub(/[ \t]+#.*$/, "", v)
      print v; exit
    }' "$1" 2>/dev/null
}

# First non-empty key among several (template key first, legacy key second).
fm_first() {
  local f="$1" k v; shift
  for k in "$@"; do v=$(parse_frontmatter "$f" "$k"); [[ -n "$v" ]] && { echo "$v"; return 0; }; done
  return 0
}

# CRITICALITY_TODAY=YYYY-MM-DD fixes "today" (reproducible reports and tests).
today_ymd() { echo "${CRITICALITY_TODAY:-$(date +%Y-%m-%d)}"; }

# ymd_epoch <YYYY-MM-DD[Thh:mm]> — UTC midnight epoch; fails on invalid dates.
# Both ends at UTC midnight: day differences are exact (no DST, no time of day).
ymd_epoch() {
  [[ "$1" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})([T\ ][0-9]{2}:[0-9]{2}(:[0-9]{2})?)?$ ]] || return 1
  local d="${BASH_REMATCH[1]}" e
  e=$(date -u -d "$d" +%s 2>/dev/null) \
    || e=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$d 00:00:00" +%s 2>/dev/null) || return 1
  [[ "$(date -u -d "@$e" +%Y-%m-%d 2>/dev/null || date -u -r "$e" +%Y-%m-%d)" == "$d" ]] || return 1
  echo "$e"
}

# valid_today — CRITICALITY_TODAY, if set, must be a real YYYY-MM-DD date.
valid_today() {
  [[ -z "${CRITICALITY_TODAY:-}" ]] && return 0
  [[ "$CRITICALITY_TODAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && ymd_epoch "$CRITICALITY_TODAY" >/dev/null
}

# deadline_days <deadline> <source> → "<days> none|ok|invalid".
# Absent or invalid deadline: 999 days (urgency stays at base 3, as without deadline).
deadline_days() {
  local dl="$1" src="$2" d t
  [[ -z "$dl" ]] && { echo "999 none"; return 0; }
  t=$(ymd_epoch "$(today_ymd)") || { echo "999 invalid"; return 0; }
  if ! d=$(ymd_epoch "$dl"); then
    crit_warn "invalid deadline '$dl' in $src; ignored"; echo "999 invalid"; return 0
  fi
  echo "$(( (d - t) / 86400 )) ok"
}

# Age against the end of the reference day: with CRITICALITY_TODAY the decay
# does not depend on the wall clock either.
file_age_days() {
  local mod ref; mod=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0)
  if [[ -n "${CRITICALITY_TODAY:-}" ]]; then
    ref=$(( $(ymd_epoch "$CRITICALITY_TODAY") + 86399 ))
  else
    ref=$(date +%s)
  fi
  echo $(( (ref - mod) / 86400 ))
}

# Text fields go to a terminal: drop control characters (ANSI escapes, BEL...).
clean_text() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177'; }

valid_project() { [[ -n "$1" && "$1" != *"/"* && "$1" != "." && "$1" != ".." ]]; }
valid_item_id() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_.#-]*$ ]]; }

# scan_items [project] — backlog .md files, sorted; exit 1 if the project has no backlog.
scan_items() {
  local project="${1:-}" dirs=() d
  if [[ -n "$project" ]]; then
    [[ -d "$WORKSPACE_ROOT/projects/$project/backlog" ]] || return 1
    dirs=("$WORKSPACE_ROOT/projects/$project/backlog")
  else
    for d in "$WORKSPACE_ROOT"/projects/*/backlog; do [[ -d "$d" ]] && dirs+=("$d"); done
  fi
  (( ${#dirs[@]} == 0 )) && return 0
  find "${dirs[@]}" -type d -name archive -prune -o -type f -name "*.md" -print 2>/dev/null | LC_ALL=C sort
}

is_active() {
  local st; st=$(fm_first "$1" state status)
  case "${st,,}" in done|closed|removed|archived|cancelled|canceled|resolved) return 1 ;; esac
  return 0
}

# find_item <id> [project] — frontmatter id match first, then filename
# (<id>.md, <id>-slug.md, <id>_slug.md), case-insensitive. One path per line.
find_item() {
  local id="${1,,}" project="${2:-}" f b fid by_id="" by_name=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    fid=$(parse_frontmatter "$f" id)
    [[ -n "$fid" && "${fid,,}" == "$id" ]] && { by_id+="$f"$'\n'; continue; }
    b=$(basename "$f" .md); b="${b,,}"
    [[ "$b" == "$id" || "$b" == "$id-"* || "$b" == "$id"_* ]] && by_name+="$f"$'\n'
  done < <(scan_items "$project")
  printf '%s' "${by_id:-$by_name}"
}

# item_metrics <file> → "score impact urgency deps conf10 eff_inv sp days_left decay% deadline_state"
item_metrics() {
  local f="$1" impact deps sp days dstate urg cpct
  impact=$(dim_value "$(parse_frontmatter "$f" impact)" 3 impact "$f")
  deps=$(dim_value "$(parse_frontmatter "$f" dependencies)" 1 dependencies "$f")
  sp=$(sp_value "$(fm_first "$f" story_points estimation_sp)" "$f")
  read -r days dstate <<< "$(deadline_days "$(parse_frontmatter "$f" deadline)" "$f")"
  urg=$(urgency_boost "$days" 3)
  cpct=$(confidence_decay "$(file_age_days "$f")")
  echo "$(compute_score "$impact" "$urg" "$deps" "$cpct" "$sp") $impact $urg $deps" \
    "$(conf_tenths "$cpct") $(effort_inverse "$sp") $sp $days $cpct $dstate"
}

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
  title=$(clean_text "$(parse_frontmatter "$f" title)"); [[ -z "$title" ]] && title="$(basename "$f" .md)"
  state=$(clean_text "$(fm_first "$f" state status)")
  assigned=$(clean_text "$(parse_frontmatter "$f" assigned_to)")
  local score impact urg deps c10 ei sp days cpct dstate dlabel
  read -r score impact urg deps c10 ei sp days cpct dstate <<< "$(item_metrics "$f")"
  case "$dstate" in ok) dlabel="${days}d" ;; invalid) dlabel="invalid deadline" ;; *) dlabel="no deadline" ;; esac

  echo "Assessment: $item_id — $title"
  echo "  State: ${state:-unknown} | SP: $sp | Assigned: ${assigned:-unassigned}"
  echo ""
  echo "  Impact       $(bar5 "$impact") $impact/5  x0.30"
  echo "  Urgency      $(bar5 "$urg") $urg/5  x0.25  ($dlabel)"
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

  local rows="" f title assigned score dstate dl alerts=()
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    is_active "$f" || continue
    title=$(clean_text "$(parse_frontmatter "$f" title)"); [[ -z "$title" ]] && title="$(basename "$f" .md)"
    assigned=$(clean_text "$(parse_frontmatter "$f" assigned_to)"); [[ -z "$assigned" ]] && assigned="?"
    read -r score _ _ _ _ _ _ _ _ dstate <<< "$(item_metrics "$f")"
    if [[ "$dstate" == invalid ]]; then
      dl=$(clean_text "$(parse_frontmatter "$f" deadline)")
      alerts+=("  ALERT: invalid deadline '$dl' — $title")
    fi
    rows+="$score"$'\t'"${title//$'\t'/ }"$'\t'"${assigned//$'\t'/ }"$'\n'
  done <<< "$items"

  local p0=() p1=() n2=0 n3=0 line s t a
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
