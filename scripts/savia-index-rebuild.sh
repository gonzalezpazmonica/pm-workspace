#!/usr/bin/env bash
# ── savia-index-rebuild.sh ──────────────────────────────────────────────────
# Git Persistence Engine: Index rebuild via branch iteration
# Called by savia-index.sh rebuild operations
# Indexes written to main:.savia-index/ via do_write
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-branch.sh"
source "$SCRIPTS_DIR/savia-compat.sh"

# Rebuild profiles.idx from user/{handle} branches
rebuild_profiles() {
  local repo_dir="${1:?}"
  local idx_path=".savia-index/profiles.idx"
  local content="handle	path	role	last_update"

  local branches; branches=$(git -C "$repo_dir" branch -r | grep "origin/user/" | sed 's|origin/||')
  echo "$branches" | while read -r branch; do
    [ -z "$branch" ] && continue
    local handle; handle=$(echo "$branch" | sed 's|^user/||')
    local profile_content; profile_content=$(do_read "$repo_dir" "$branch" "profile.md") || continue
    local role; role=$(echo "$profile_content" | grep "^role:" | cut -d: -f2 | xargs || echo "member")
    content="${content}
${handle}	user/${handle}	${role}	$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  done

  do_write "$repo_dir" "main" "$idx_path" "$content" "[index: rebuild-profiles]"
  echo "✅ Rebuilt profiles index"
}

# Rebuild teams.idx from team/{name} branches
rebuild_teams() {
  local repo_dir="${1:?}"
  local idx_path=".savia-index/teams.idx"
  local content="team	members	path"

  local branches; branches=$(git -C "$repo_dir" branch -r | grep "origin/team/" | sed 's|origin/||')
  echo "$branches" | while read -r branch; do
    [ -z "$branch" ] && continue
    local team; team=$(echo "$branch" | sed 's|^team/||')
    local team_content; team_content=$(do_read "$repo_dir" "$branch" "team.md") || continue
    content="${content}
${team}	$(echo "$team_content" | grep -c "@" || echo 0)	team/${team}"
  done

  do_write "$repo_dir" "main" "$idx_path" "$content" "[index: rebuild-teams]"
  echo "✅ Rebuilt teams index"
}

# Rebuild inboxes.idx from user/{handle}/inbox/
rebuild_inboxes() {
  local repo_dir="${1:?}"
  local idx_path=".savia-index/inboxes.idx"
  local content="handle	unread_count	path"

  local branches; branches=$(git -C "$repo_dir" branch -r | grep "origin/user/" | sed 's|origin/||')
  echo "$branches" | while read -r branch; do
    [ -z "$branch" ] && continue
    local handle; handle=$(echo "$branch" | sed 's|^user/||')
    local inbox_list; inbox_list=$(do_list "$repo_dir" "$branch" "inbox/unread") || continue
    local count; count=$(echo "$inbox_list" | grep -c "." || echo 0)
    content="${content}
${handle}	${count}	user/${handle}/inbox"
  done

  do_write "$repo_dir" "main" "$idx_path" "$content" "[index: rebuild-inboxes]"
  echo "✅ Rebuilt inboxes index"
}

# Rebuild timesheets.idx from user/{handle}/flow/timesheet/
rebuild_timesheets() {
  local repo_dir="${1:?}"
  local idx_path=".savia-index/timesheets.idx"
  local content="handle	month	path	total_h"

  local branches; branches=$(git -C "$repo_dir" branch -r | grep "origin/user/" | sed 's|origin/||')
  echo "$branches" | while read -r branch; do
    [ -z "$branch" ] && continue
    local handle; handle=$(echo "$branch" | sed 's|^user/||')
    local ts_list; ts_list=$(do_list "$repo_dir" "$branch" "flow/timesheet") || continue
    echo "$ts_list" | while read -r ts_file; do
      [ -z "$ts_file" ] && continue
      local month; month=$(echo "$ts_file" | sed 's/\.md$//')
      content="${content}
${handle}	${month}	user/${handle}/flow/timesheet/${ts_file}	0"
    done
  done

  do_write "$repo_dir" "main" "$idx_path" "$content" "[index: rebuild-timesheets]"
  echo "✅ Rebuilt timesheets index"
}

# Rebuild all indexes
rebuild_all() {
  local repo_dir="${1:?}"
  rebuild_profiles "$repo_dir"
  rebuild_teams "$repo_dir"
  rebuild_inboxes "$repo_dir"
  rebuild_timesheets "$repo_dir"
  echo "✅ All indexes rebuilt on main branch"
}

case "${1:-all}" in
  all) rebuild_all "${2:?}" ;;
  profiles) rebuild_profiles "${2:?}" ;;
  teams) rebuild_teams "${2:?}" ;;
  inboxes) rebuild_inboxes "${2:?}" ;;
  timesheets) rebuild_timesheets "${2:?}" ;;
  *) echo "Modes: all|profiles|teams|inboxes|timesheets"; exit 1 ;;
esac
