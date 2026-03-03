#!/usr/bin/env bash
# ── savia-index-rebuild.sh ──────────────────────────────────────────────────
# Git Persistence Engine: Index rebuild logic.
# Called by savia-index.sh rebuild operations.
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

INDEX_DIR=".savia-index"
MKDIR="${MKDIR:-mkdir -p}"
SED="${SED:-sed}"

ensure_index_dir() {
  "$MKDIR" "$INDEX_DIR" 2>/dev/null || true
}

init_index() {
  local index_name="$1"
  local header="$2"
  ensure_index_dir
  echo "$header" > "$INDEX_DIR/$index_name.idx"
}

# Rebuild profiles.idx from profile.md files in users/{handle}/
rebuild_profiles() {
  init_index "profiles" "handle\tpath\trole\tlast_update"
  local idx="$INDEX_DIR/profiles.idx"
  find users/*/profile.md -type f 2>/dev/null | while read -r f; do
    local handle dir role date
    dir="$(dirname "$f")"
    handle="$(basename "$dir")"
    role="$(grep "^role:" "$f" 2>/dev/null | cut -d: -f2 | xargs || echo "member")"
    date="$(date -r "$f" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo 'unknown')"
    echo -e "$handle\t$dir\t$role\t$date"
  done >> "$idx"
}

# Note: rebuild_messages, rebuild_projects, rebuild_specs unchanged from original
# Delegate to scripts/savia-index-rebuild-extended.sh if needed

# Rebuild timesheets.idx from users/{handle}/flow/timesheet/
rebuild_timesheets() {
  init_index "timesheets" "handle\tmonth\tpath\ttotal_h"
  local idx="$INDEX_DIR/timesheets.idx"
  find users/*/flow/timesheet -name "*.md" -type f 2>/dev/null | while read -r f; do
    local handle month total_h
    handle="$(echo "$f" | cut -d'/' -f2)"
    month="$(basename "$f" .md)"
    total_h="$(grep "Total:" "$f" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo '0')"
    echo -e "$handle\t$month\t$f\t$total_h"
  done >> "$idx"
}

# Rebuild inboxes.idx from users/{handle}/inbox/
rebuild_inboxes() {
  init_index "inboxes" "handle\tinbox_path"
  local idx="$INDEX_DIR/inboxes.idx"
  for dir in users/*/; do
    [ -d "$dir" ] || continue
    local h="$(basename "$dir")"
    [ -d "$dir/inbox" ] && echo -e "$h\tusers/$h/inbox" >> "$idx"
  done
}

# Rebuild teams.idx from teams/{team}/users/
rebuild_teams() {
  init_index "teams" "team\tmembers"
  local idx="$INDEX_DIR/teams.idx"
  for dir in teams/*/; do
    [ -d "$dir" ] || continue
    local t="$(basename "$dir")"
    local members=""
    for u in "$dir"/users/*.md; do
      [ -f "$u" ] || continue
      members="${members:+$members,}$(basename "$u" .md)"
    done
    [ -n "$members" ] && echo -e "$t\t$members" >> "$idx"
  done
}

# Rebuild all indexes (profile, timesheets, inboxes, teams only)
rebuild_all() {
  rebuild_profiles
  rebuild_timesheets
  rebuild_inboxes
  rebuild_teams
  echo "Indexes rebuilt: profiles, timesheets, inboxes, teams"
  echo "(messages, projects, specs handled separately)"
}

case "${1:-all}" in
  all) rebuild_all ;;
  profiles) rebuild_profiles ;;
  timesheets) rebuild_timesheets ;;
  inboxes) rebuild_inboxes ;;
  teams) rebuild_teams ;;
  *) echo "Modes: all|profiles|timesheets|inboxes|teams"; exit 1 ;;
esac
