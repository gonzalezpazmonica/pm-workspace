#!/bin/bash
# savia-messaging-actions.sh — Announce, broadcast, and directory operations
# Sourced by savia-messaging.sh — do NOT run directly.

# ── Announce: post to main:company/inbox/ ───────────────────────────
do_announce() {
  local subject="${1:?Uso: savia-messaging.sh announce <subject> <body> [--priority high]}"
  local body="${2:?Falta body}"
  local priority="normal"
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in --priority) shift; priority="${1:-normal}" ;; esac
    shift
  done

  local repo_dir handle msg_id
  repo_dir=$(get_repo)
  handle=$(get_handle)
  msg_id=$(gen_id)

  local msg_content
  msg_content=$(cat <<EOF
---
id: "${msg_id}"
from: "@${handle}"
to: "all"
date: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
subject: "${subject}"
priority: "${priority}"
type: "announcement"
encrypted: false
---

${body}
EOF
)

  bash "$SCRIPTS_DIR/savia-branch.sh" write "$repo_dir" main "company/inbox/${msg_id}.md" "$msg_content" \
    "[main] announce: $subject"

  log_ok "Announcement posted: $subject"
  echo "  ID: $msg_id"
}

# ── Broadcast: send encrypted to all handles via exchange ──────────
do_broadcast() {
  local subject="${1:?Uso: savia-messaging.sh broadcast <subject> <body>}"
  local body="${2:?Falta body}"
  shift 2

  local repo_dir handle count=0
  repo_dir=$(get_repo)
  handle=$(get_handle)

  local directory
  directory=$(bash "$SCRIPTS_DIR/savia-branch.sh" read "$repo_dir" main "directory.md") || { log_error "No directory found"; return 1; }

  while IFS= read -r line; do
    [[ "$line" =~ ^@([a-zA-Z0-9_-]+) ]] || continue
    local target="${BASH_REMATCH[1]}"
    [ "$target" = "$handle" ] && continue
    do_send "$target" "$subject" "$body" "$@" 2>/dev/null && count=$((count + 1))
  done <<< "$directory"

  log_ok "Broadcast sent to $count recipient(s)"
}

# ── Directory: read from main:directory.md ───────────────────────────
do_directory() {
  local repo_dir
  repo_dir=$(get_repo)

  local directory
  directory=$(bash "$SCRIPTS_DIR/savia-branch.sh" read "$repo_dir" main "directory.md") || { log_error "No directory.md found"; return 1; }
  echo "$directory"
}
