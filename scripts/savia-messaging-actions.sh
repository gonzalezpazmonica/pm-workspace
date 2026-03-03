#!/bin/bash
# savia-messaging-actions.sh — Announce, broadcast, and directory operations
# Sourced by savia-messaging.sh — do NOT run directly.

# ── Announce: post to company-inbox ────────────────────────────────
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

  mkdir -p "$repo_dir/company-inbox"

  cat > "$repo_dir/company-inbox/${msg_id}.md" <<EOF
---
id: "${msg_id}"
from: "${handle}"
to: "all"
date: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
subject: "${subject}"
priority: "${priority}"
type: "announcement"
encrypted: false
---

${body}
EOF

  log_ok "Announcement posted: $subject"
  echo "  ID: $msg_id"
}

# ── Broadcast: send to all handles ─────────────────────────────────
do_broadcast() {
  local subject="${1:?Uso: savia-messaging.sh broadcast <subject> <body>}"
  local body="${2:?Falta body}"
  shift 2

  local repo_dir handle count=0
  repo_dir=$(get_repo)
  handle=$(get_handle)

  for user_dir in "$repo_dir"/team/*/; do
    [ -d "$user_dir" ] || continue
    local target
    target=$(basename "$user_dir")
    [ "$target" = "$handle" ] && continue
    do_send "$target" "$subject" "$body" "$@" 2>/dev/null && count=$((count + 1))
  done

  log_ok "Broadcast sent to $count recipient(s)"
}

# ── Directory: list team members ───────────────────────────────────
do_directory() {
  local repo_dir
  repo_dir=$(get_repo)

  if [ -f "$repo_dir/directory.md" ]; then
    cat "$repo_dir/directory.md"
  else
    log_warn "No directory.md found"
  fi
}
