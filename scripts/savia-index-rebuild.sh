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

# Rebuild profiles.idx from identity.md files
rebuild_profiles() {
  init_index "profiles" "handle\tpath\trole\tlast_update"
  local idx="$INDEX_DIR/profiles.idx"
  find . -name "identity.md" -type f 2>/dev/null | while read -r f; do
    local handle dir role date
    dir="$(dirname "$f")"
    handle="$(grep "^handle:" "$f" 2>/dev/null | cut -d: -f2 | xargs || echo "unknown")"
    role="$(grep "^role:" "$f" 2>/dev/null | cut -d: -f2 | xargs || echo "member")"
    date="$(date -r "$f" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo 'unknown')"
    echo -e "$handle\t$dir\t$role\t$date"
  done >> "$idx"
}

# Rebuild messages.idx from company-savia
rebuild_messages() {
  init_index "messages" "msg_id\tpath\tfrom\tto\tsubject\tdate\tthread_id"
  local idx="$INDEX_DIR/messages.idx"
  find .pm-workspace/company-savia -name "*.msg" -type f 2>/dev/null | while read -r f; do
    local msg_id from to subject date thread_id
    msg_id="$(basename "$f" .msg)"
    from="$(grep "^From:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo 'unknown')"
    to="$(grep "^To:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo 'unknown')"
    subject="$(grep "^Subject:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo 'no-subject')"
    date="$(grep "^Date:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo 'unknown')"
    thread_id="$(grep "^Thread-ID:" "$f" 2>/dev/null | cut -d: -f2 | xargs || echo 'single')"
    echo -e "$msg_id\t$f\t$from\t$to\t$subject\t$date\t$thread_id"
  done >> "$idx"
}

# Rebuild projects.idx from CLAUDE.md
rebuild_projects() {
  init_index "projects" "name\tpath\tstatus\tlast_activity"
  local idx="$INDEX_DIR/projects.idx"
  find projects -name "CLAUDE.md" -type f 2>/dev/null | while read -r f; do
    local name dir status date
    dir="$(dirname "$f")"
    name="$(grep "^name:" "$f" 2>/dev/null | cut -d: -f2 | xargs || basename "$dir")"
    status="$(grep "^status:" "$f" 2>/dev/null | cut -d: -f2 | xargs || echo 'active')"
    date="$(date -r "$f" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo 'unknown')"
    echo -e "$name\t$dir\t$status\t$date"
  done >> "$idx"
}

# Rebuild specs.idx from .spec.md files
rebuild_specs() {
  init_index "specs" "spec_id\tpath\tstatus\tauthor\tdate"
  local idx="$INDEX_DIR/specs.idx"
  find projects -name "*.spec.md" -type f 2>/dev/null | while read -r f; do
    local spec_id status author date
    spec_id="$(basename "$f" .spec.md)"
    status="$(grep "^status:" "$f" 2>/dev/null | cut -d: -f2 | xargs || echo 'draft')"
    author="$(grep "^author:" "$f" 2>/dev/null | cut -d: -f2 | xargs || echo 'unknown')"
    date="$(date -r "$f" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo 'unknown')"
    echo -e "$spec_id\t$f\t$status\t$author\t$date"
  done >> "$idx"
}

# Rebuild timesheets.idx from timesheet files
rebuild_timesheets() {
  init_index "timesheets" "handle\tdate\tpath\ttotal_h"
  local idx="$INDEX_DIR/timesheets.idx"
  find .pm-workspace -name "timesheet-*.md" -type f 2>/dev/null | while read -r f; do
    local handle date total_h
    handle="$(basename "$f" | sed 's/timesheet-//;s/-.*//')"
    date="$(basename "$f" | sed 's/.*-\([0-9-]*\)\.md/\1/')"
    total_h="$(grep "^Total:" "$f" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo '0')"
    echo -e "$handle\t$date\t$f\t$total_h"
  done >> "$idx"
}

# Rebuild all indexes
rebuild_all() {
  rebuild_profiles
  rebuild_messages
  rebuild_projects
  rebuild_specs
  rebuild_timesheets
}

# Main dispatch
case "${1:-all}" in
  all)
    rebuild_all
    ;;
  profiles)
    rebuild_profiles
    ;;
  messages)
    rebuild_messages
    ;;
  projects)
    rebuild_projects
    ;;
  specs)
    rebuild_specs
    ;;
  timesheets)
    rebuild_timesheets
    ;;
  *)
    echo "Unknown rebuild mode: $1"
    echo "Valid modes: all|profiles|messages|projects|specs|timesheets"
    exit 1
    ;;
esac
