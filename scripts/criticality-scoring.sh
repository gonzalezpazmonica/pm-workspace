#!/usr/bin/env bash
# criticality-scoring.sh — Pure scoring functions. Sourced by criticality-engine.sh.
set -uo pipefail

W_IMPACT=30 W_URGENCY=25 W_DEPS=20 W_CONF=15 W_EFFORT=10

confidence_decay() {
  local days="${1:-0}"
  if   (( days <= 14 )); then echo 100
  elif (( days <= 30 )); then echo 90
  elif (( days <= 60 )); then echo 75
  elif (( days <= 90 )); then echo 50
  else echo 30; fi
}

urgency_boost() {
  local days_left="${1:-999}" base="${2:-3}"
  if   (( days_left <= 0 ));  then echo 5
  elif (( days_left <= 2 ));  then local v=$((base+3)); (( v>5 )) && v=5; echo "$v"
  elif (( days_left <= 7 ));  then local v=$((base+2)); (( v>5 )) && v=5; echo "$v"
  elif (( days_left <= 14 )); then local v=$((base+1)); (( v>5 )) && v=5; echo "$v"
  else echo "$base"; fi
}

effort_inverse() {
  local sp="${1:-3}"
  local c=$(( (sp + 3) / 4 )); (( c > 5 )) && c=5
  echo $(( 6 - c ))
}

compute_score() {
  local impact="${1:-3}" urgency="${2:-3}" deps="${3:-1}" conf_pct="${4:-100}" sp="${5:-3}"
  local ei; ei=$(effort_inverse "$sp")
  local conf_dim=$(( 5 * conf_pct / 100 )); (( conf_dim < 1 )) && conf_dim=1
  local raw=$(( impact*W_IMPACT + urgency*W_URGENCY + deps*W_DEPS + conf_dim*W_CONF + ei*W_EFFORT ))
  echo $(( raw * 10 / 100 ))
}

classify() {
  local s="$1"
  if   (( s >= 40 )); then echo "P0 Critical"
  elif (( s >= 30 )); then echo "P1 High"
  elif (( s >= 20 )); then echo "P2 Medium"
  else echo "P3 Low"; fi
}

score_display() { echo "$((${1}/10)).$((${1}%10))"; }

bar5() {
  local v="$1" b=""
  for i in 1 2 3 4 5; do (( i <= v )) && b+="█" || b+="░"; done
  echo "$b"
}

parse_frontmatter() {
  sed -n '/^---$/,/^---$/p' "$1" 2>/dev/null | grep -oP "^${2}:\s*\K.*" | head -1
}

today_epoch() { date +%s; }

date_epoch() {
  date -d "$1" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null || echo 0
}

days_between() { echo $(( ($2 - $1) / 86400 )); }

file_age_days() {
  local mod; mod=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0)
  echo $(( ($(today_epoch) - mod) / 86400 ))
}

scan_items() {
  local project="${1:-}" dirs=()
  if [[ -n "$project" ]]; then
    dirs=("$WORKSPACE_ROOT/projects/$project/backlog")
  else
    for d in "$WORKSPACE_ROOT"/projects/*/backlog; do [[ -d "$d" ]] && dirs+=("$d"); done
  fi
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] && find "$d" -name "*.md" -print 2>/dev/null
  done
}

score_item() {
  local f="$1"
  local sp; sp=$(parse_frontmatter "$f" "story_points"); [[ -z "$sp" ]] && sp=3
  local impact; impact=$(parse_frontmatter "$f" "impact"); [[ -z "$impact" ]] && impact=3
  local deps; deps=$(parse_frontmatter "$f" "dependencies"); [[ -z "$deps" ]] && deps=1
  local deadline; deadline=$(parse_frontmatter "$f" "deadline")
  local days_left=999
  [[ -n "$deadline" ]] && days_left=$(days_between "$(today_epoch)" "$(date_epoch "$deadline")")
  local urgency; urgency=$(urgency_boost "$days_left" 3)
  local cpct; cpct=$(confidence_decay "$(file_age_days "$f")")
  compute_score "$impact" "$urgency" "$deps" "$cpct" "$sp"
}
