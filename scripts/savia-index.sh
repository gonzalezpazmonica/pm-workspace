#!/usr/bin/env bash
# ── savia-index.sh ──────────────────────────────────────────────────────────
# Git Persistence Engine: Core index operations via branch isolation on main
# Indexes live on main branch in .savia-index/ directory
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-compat.sh"
source "$SCRIPTS_DIR/savia-branch.sh"

# Index operations on main branch
lookup() {
  local repo_dir="${1:?}" index_name="${2:?}" key="${3:?}"
  local idx_path=".savia-index/${index_name}.idx"
  local content; content=$(do_read "$repo_dir" "main" "$idx_path") || { echo "INDEX_NOT_FOUND"; return 1; }
  echo "$content" | grep "^$key" || echo "NOT_FOUND"
}

update_entry() {
  local repo_dir="${1:?}" index_name="${2:?}" key="${3:?}"
  shift 3
  local value="$@"
  local idx_path=".savia-index/${index_name}.idx"
  local content; content=$(do_read "$repo_dir" "main" "$idx_path") || content="# Index: $index_name"

  content=$(echo "$content" | grep -v "^$key\t" || echo "$content")
  content="${content}
${key}	${value}"

  do_write "$repo_dir" "main" "$idx_path" "$content" "[index: update] $index_name/$key"
}

remove_entry() {
  local repo_dir="${1:?}" index_name="${2:?}" key="${3:?}"
  local idx_path=".savia-index/${index_name}.idx"
  local content; content=$(do_read "$repo_dir" "main" "$idx_path") || return 0
  content=$(echo "$content" | grep -v "^$key\t" || echo "$content")
  do_write "$repo_dir" "main" "$idx_path" "$content" "[index: remove] $index_name/$key"
}

verify_index() {
  local repo_dir="${1:?}" index_name="${2:-profiles}"
  local idx_path=".savia-index/${index_name}.idx"
  local content; content=$(do_read "$repo_dir" "main" "$idx_path") || { echo "INDEX_NOT_FOUND"; return 1; }
  local entries; entries=$(echo "$content" | tail -n +2 | wc -l | tr -d ' ')
  echo "index=${index_name}|entries=$entries|branch=main"
}

compact_index() {
  echo "ℹ️  Index compaction via branch isolation (on-read deduplication)"
}

case "${1:-help}" in
  rebuild|rebuild-*) bash "$SCRIPTS_DIR/savia-index-rebuild.sh" "${1#rebuild-}" ;;
  lookup) lookup "${2:?}" "${3:?}" "${4:?}" ;;
  update) update_entry "${2:?}" "${3:?}" "${4:?}" "${@:5}" ;;
  remove) remove_entry "${2:?}" "${3:?}" "${4:?}" ;;
  verify) verify_index "${2:?}" "${3:-profiles}" ;;
  compact) compact_index "${2:-profiles}" ;;
  help|*) cat <<EOF
Git Persistence Engine — Savia Index (Branch-Isolated)
Usage: savia-index.sh <command> <repo_dir> [args]

CORE:  lookup <repo> <index> <key>
       update <repo> <index> <key> <value...>
       remove <repo> <index> <key>
       verify <repo> [index]
       compact <repo> [index]
REBUILD: rebuild <repo> [mode: all|profiles|teams|inboxes|timesheets]

All indexes live on main branch in .savia-index/
EOF
    ;;
esac
