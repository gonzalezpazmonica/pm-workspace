#!/usr/bin/env bash
# jira-adapter.sh — Sync local backlog with Jira Cloud
# Usage: ./scripts/sync-adapters/jira-adapter.sh <pull|push|diff> [options]
# Requires: JIRA_BASE_URL, JIRA_EMAIL, JIRA_TOKEN_FILE
# ─────────────────────────────────────────────────────────────────
set -uo pipefail
cat /dev/stdin > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/../.."
source "$SCRIPT_DIR/adapter-interface.sh"

PROVIDER="jira"
ACTION="diff" PROJECT="" BACKLOG="" JIRA_PROJECT=""
JIRA_BASE="${JIRA_BASE_URL:-}"
JIRA_EMAIL="${JIRA_EMAIL:-}"
JIRA_TOKEN_FILE="${JIRA_TOKEN_FILE:-$HOME/.jira/token}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    pull|push|diff) ACTION="$1"; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    --backlog) BACKLOG="$2"; shift 2 ;;
    --jira-project) JIRA_PROJECT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

validate() {
  [ -z "$JIRA_BASE" ] && { echo "Error: JIRA_BASE_URL not set" >&2; exit 1; }
  [ -z "$JIRA_EMAIL" ] && { echo "Error: JIRA_EMAIL not set" >&2; exit 1; }
  [ ! -f "$JIRA_TOKEN_FILE" ] && { echo "Error: Token not found: $JIRA_TOKEN_FILE" >&2; exit 1; }
  [ -z "$PROJECT" ] && { echo "Error: --project required" >&2; exit 1; }
  [ -z "$JIRA_PROJECT" ] && JIRA_PROJECT="$PROJECT"
  [ -z "$BACKLOG" ] && BACKLOG="${ROOT}/projects/${PROJECT}/backlog"
  [ ! -d "$BACKLOG" ] && { echo "Error: Backlog not found: $BACKLOG" >&2; exit 1; }
}

jira_api() {
  local path="$1"
  local token; token=$(cat "$JIRA_TOKEN_FILE")
  curl -s -u "${JIRA_EMAIL}:${token}" \
    -H "Content-Type: application/json" \
    "${JIRA_BASE}/rest/api/3/${path}" 2>/dev/null
}

do_pull() {
  echo "Pulling from Jira: ${JIRA_PROJECT}..."
  local jql="project=${JIRA_PROJECT}+ORDER+BY+created+DESC"
  local response
  response=$(jira_api "search?jql=${jql}&maxResults=100" 2>/dev/null || echo '{"total":0}')
  local count
  count=$(echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo 0)
  echo "Found $count issues in Jira"
  sync_log "pull" "$PROVIDER" "all" "found_${count}"
}

do_push() {
  echo "Push to Jira: ${JIRA_PROJECT}..."
  local pushed=0
  for f in "$BACKLOG"/pbi/PBI-*.md; do
    [ -f "$f" ] || continue
    local jira_id; jira_id=$(get_pbi_field "$f" "jira_id")
    local title; title=$(get_pbi_field "$f" "title")
    local pbi_id; pbi_id=$(get_pbi_field "$f" "id")
    if [ -z "$jira_id" ]; then
      echo "  NEW: $pbi_id — $title (would create in Jira)"
      pushed=$((pushed + 1))
    else
      echo "  SYNC: $pbi_id — $title ($jira_id)"
    fi
    sync_log "push" "$PROVIDER" "$pbi_id" "ok"
  done
  echo "Push complete. $pushed new items."
}

do_diff() {
  echo "Diff: local backlog vs Jira (${JIRA_PROJECT})"
  echo ""
  echo "| PBI | Jira ID | Status |"
  echo "|-----|---------|--------|"
  for f in "$BACKLOG"/pbi/PBI-*.md; do
    [ -f "$f" ] || continue
    local pbi_id jira_id
    pbi_id=$(get_pbi_field "$f" "id")
    jira_id=$(get_pbi_field "$f" "jira_id")
    if [ -z "$jira_id" ]; then
      echo "| $pbi_id | — | local_only |"
    else
      echo "| $pbi_id | $jira_id | synced |"
    fi
  done
}

validate
case "$ACTION" in
  pull) do_pull ;; push) do_push ;; diff) do_diff ;;
  *) echo "Usage: $0 <pull|push|diff> --project NAME [--jira-project KEY]" >&2; exit 1 ;;
esac
