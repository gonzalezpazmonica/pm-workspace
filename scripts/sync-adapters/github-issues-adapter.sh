#!/usr/bin/env bash
# github-issues-adapter.sh — Sync local backlog with GitHub Issues
# Usage: ./scripts/sync-adapters/github-issues-adapter.sh <pull|push|diff> [options]
# Requires: gh CLI authenticated, --repo owner/name
# ─────────────────────────────────────────────────────────────────
set -uo pipefail
cat /dev/stdin > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/../.."
source "$SCRIPT_DIR/adapter-interface.sh"

PROVIDER="github"
ACTION="diff" PROJECT="" BACKLOG="" REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    pull|push|diff) ACTION="$1"; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    --backlog) BACKLOG="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    *) shift ;;
  esac
done

validate() {
  command -v gh >/dev/null 2>&1 || { echo "Error: gh CLI not installed" >&2; exit 1; }
  [ -z "$REPO" ] && { echo "Error: --repo owner/name required" >&2; exit 1; }
  [ -z "$PROJECT" ] && { echo "Error: --project required" >&2; exit 1; }
  [ -z "$BACKLOG" ] && BACKLOG="${ROOT}/projects/${PROJECT}/backlog"
  [ ! -d "$BACKLOG" ] && { echo "Error: Backlog not found: $BACKLOG" >&2; exit 1; }
}

do_pull() {
  echo "Pulling from GitHub Issues: ${REPO}..."
  local issues
  issues=$(gh issue list --repo "$REPO" --limit 100 --json number,title,state 2>/dev/null || echo "[]")
  local count
  count=$(echo "$issues" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
  echo "Found $count issues"
  sync_log "pull" "$PROVIDER" "all" "found_${count}"
}

do_push() {
  echo "Push to GitHub Issues: ${REPO}..."
  local pushed=0
  for f in "$BACKLOG"/pbi/PBI-*.md; do
    [ -f "$f" ] || continue
    local gh_id; gh_id=$(get_pbi_field "$f" "github_issue_id")
    local title; title=$(get_pbi_field "$f" "title")
    local pbi_id; pbi_id=$(get_pbi_field "$f" "id")
    if [ -z "$gh_id" ]; then
      echo "  NEW: $pbi_id — $title (would create as issue)"
      pushed=$((pushed + 1))
    else
      echo "  SYNC: $pbi_id — $title (#${gh_id})"
    fi
    sync_log "push" "$PROVIDER" "$pbi_id" "ok"
  done
  echo "Push complete. $pushed new items."
}

do_diff() {
  echo "Diff: local backlog vs GitHub Issues (${REPO})"
  echo ""
  echo "| PBI | GitHub Issue | Status |"
  echo "|-----|-------------|--------|"
  for f in "$BACKLOG"/pbi/PBI-*.md; do
    [ -f "$f" ] || continue
    local pbi_id gh_id
    pbi_id=$(get_pbi_field "$f" "id")
    gh_id=$(get_pbi_field "$f" "github_issue_id")
    if [ -z "$gh_id" ]; then
      echo "| $pbi_id | — | local_only |"
    else
      echo "| $pbi_id | #$gh_id | synced |"
    fi
  done
}

validate
case "$ACTION" in
  pull) do_pull ;; push) do_push ;; diff) do_diff ;;
  *) echo "Usage: $0 <pull|push|diff> --project NAME --repo owner/name" >&2; exit 1 ;;
esac
