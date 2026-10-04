#!/usr/bin/env bash
# criticality-items.sh — Local backlog access for the criticality engine:
# frontmatter parsing, dates, item lookup and per-item metrics.
# Sourced by criticality-engine.sh (needs criticality-scoring.sh and WORKSPACE_ROOT).
# Accepts the local PBI template (id/state/estimation_sp) and the legacy keys
# (status/story_points). Items under backlog/**/archive/ are ignored.
set -uo pipefail

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
