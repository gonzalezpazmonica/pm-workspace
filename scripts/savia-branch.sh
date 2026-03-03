#!/bin/bash
# savia-branch.sh — Git branch abstraction layer for Company Savia v3
# Provides cross-branch read/write/list without checkout switching.
# Uses git show, git ls-tree, and temporary worktrees for writes.
#
# Usage: bash savia-branch.sh <command> [args...]
# Commands: read, list, write, exists, ensure-orphan, check-permission, fetch-messages

set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS_DIR/savia-compat.sh"

# ── Read file from branch without checkout ─────────────────────
do_read() {
  local repo_dir="$1" branch="$2" filepath="$3"
  git -C "$repo_dir" show "origin/${branch}:${filepath}" 2>/dev/null \
    || git -C "$repo_dir" show "${branch}:${filepath}" 2>/dev/null \
    || { echo ""; return 1; }
}

# ── List directory contents on branch ──────────────────────────
do_list() {
  local repo_dir="$1" branch="$2" dir="$3"
  git -C "$repo_dir" ls-tree --name-only \
    "origin/${branch}" -- "${dir}/" 2>/dev/null \
    || git -C "$repo_dir" ls-tree --name-only \
    "${branch}" -- "${dir}/" 2>/dev/null \
    || echo ""
}

# ── Write file to specific branch via worktree ─────────────────
do_write() {
  local repo_dir="$1" branch="$2" filepath="$3" content="$4"
  local msg="${5:-"auto: update $filepath"}"
  local wtdir
  wtdir=$(mktemp -d)
  trap "rm -rf '$wtdir'" RETURN
  git -C "$repo_dir" worktree add -f "$wtdir" "$branch" 2>/dev/null \
    || git -C "$repo_dir" worktree add -f "$wtdir" "origin/$branch" 2>/dev/null
  local dir
  dir=$(dirname "$wtdir/$filepath")
  mkdir -p "$dir"
  echo "$content" > "$wtdir/$filepath"
  git -C "$wtdir" add "$filepath"
  git -C "$wtdir" commit -m "$msg" 2>/dev/null || true
  git -C "$wtdir" push origin "$branch" 2>/dev/null || true
  git -C "$repo_dir" worktree remove "$wtdir" 2>/dev/null || rm -rf "$wtdir"
}

# ── Check if branch exists (local or remote) ──────────────────
do_exists() {
  local repo_dir="$1" branch="$2"
  git -C "$repo_dir" rev-parse --verify "origin/${branch}" >/dev/null 2>&1 \
    || git -C "$repo_dir" rev-parse --verify "${branch}" >/dev/null 2>&1
}

# ── Create orphan branch if it doesn't exist (idempotent) ─────
do_ensure_orphan() {
  local repo_dir="$1" branch="$2" msg="${3:-"init: $2 branch"}"
  if do_exists "$repo_dir" "$branch"; then
    return 0
  fi
  local wtdir
  wtdir=$(mktemp -d)
  trap "rm -rf '$wtdir'" RETURN
  git -C "$repo_dir" worktree add --detach "$wtdir" 2>/dev/null || {
    # Fallback: if no commits yet, init in place
    cd "$wtdir"
    git init && git remote add origin "$(git -C "$repo_dir" remote get-url origin)"
  }
  cd "$wtdir"
  git checkout --orphan "$branch"
  git rm -rf . 2>/dev/null || true
  echo "# $branch" > README.md
  mkdir -p .gitkeep 2>/dev/null || true
  git add README.md
  git commit -m "$msg"
  git push origin "$branch" 2>/dev/null || true
  cd "$repo_dir"
  git -C "$repo_dir" worktree remove "$wtdir" 2>/dev/null || rm -rf "$wtdir"
  git -C "$repo_dir" fetch origin "$branch" 2>/dev/null || true
}

# ── Validate write permission for handle on branch ─────────────
do_check_permission() {
  local branch="$1" handle="$2" role="${3:-member}"
  case "$branch" in
    main)
      [ "$role" = "admin" ] && return 0 || return 1
      ;;
    user/*)
      local owner="${branch#user/}"
      [ "$handle" = "$owner" ] && return 0 || return 1
      ;;
    team/*)
      # Team members can push — caller verifies membership
      return 0
      ;;
    exchange)
      # Anyone can push to exchange
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# ── Fetch pending messages for handle from exchange ─────────────
do_fetch_messages() {
  local repo_dir="$1" handle="$2"
  git -C "$repo_dir" fetch origin exchange 2>/dev/null || return 0
  local files
  files=$(do_list "$repo_dir" exchange "pending") || return 0
  [ -z "$files" ] && return 0
  local count=0
  while IFS= read -r fpath; do
    [ -z "$fpath" ] && continue
    local fname
    fname=$(basename "$fpath")
    local content
    content=$(do_read "$repo_dir" exchange "$fpath") || continue
    local to_field
    to_field=$(echo "$content" | grep '^to:' | head -1 \
      | sed 's/to:[[:space:]]*"\{0,1\}@\{0,1\}\([^"]*\)"\{0,1\}/\1/')
    [ "$to_field" = "$handle" ] || continue
    # Deliver to user branch
    do_write "$repo_dir" "user/$handle" "inbox/unread/$fname" "$content" \
      "[user/$handle] inbox: received $fname"
    count=$((count + 1))
  done <<< "$files"
  echo "$count"
}

# ── Dispatcher ─────────────────────────────────────────────────
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
cmd="${1:-help}"; shift
case "$cmd" in
  read)             do_read "$@" ;;
  list)             do_list "$@" ;;
  write)            do_write "$@" ;;
  exists)           do_exists "$@" ;;
  ensure-orphan)    do_ensure_orphan "$@" ;;
  check-permission) do_check_permission "$@" ;;
  fetch-messages)   do_fetch_messages "$@" ;;
  *) echo "Usage: savia-branch.sh {read|list|write|exists|ensure-orphan|check-permission|fetch-messages}" ;;
esac
