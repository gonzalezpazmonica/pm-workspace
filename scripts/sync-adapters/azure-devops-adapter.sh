#!/usr/bin/env bash
# azure-devops-adapter.sh — Sync local backlog with Azure DevOps
# Usage: ./scripts/sync-adapters/azure-devops-adapter.sh <pull|push|diff> [options]
# Requires: AZURE_DEVOPS_ORG_URL, PAT file, project name
# ─────────────────────────────────────────────────────────────────
set -uo pipefail
cat /dev/stdin > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/../.."
source "$SCRIPT_DIR/adapter-interface.sh"

PROVIDER="azure-devops"
PAT_FILE="${HOME}/.azure/devops-pat"
ORG_URL="${AZURE_DEVOPS_ORG_URL:-}"
PROJECT="" BACKLOG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    pull|push|diff) ACTION="$1"; shift ;;
    --project) PROJECT="$2"; shift 2 ;;
    --backlog) BACKLOG="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# ── Validate prerequisites ──
validate() {
  [ -z "$ORG_URL" ] && { echo "Error: AZURE_DEVOPS_ORG_URL not set" >&2; exit 1; }
  [ ! -f "$PAT_FILE" ] && { echo "Error: PAT file not found: $PAT_FILE" >&2; exit 1; }
  [ -z "$PROJECT" ] && { echo "Error: --project required" >&2; exit 1; }
  [ -z "$BACKLOG" ] && BACKLOG="${ROOT}/projects/${PROJECT}/backlog"
  [ ! -d "$BACKLOG" ] && { echo "Error: Backlog not found: $BACKLOG" >&2; exit 1; }
}

# ── API call helper ──
az_api() {
  local path="$1"
  local pat; pat=$(cat "$PAT_FILE")
  curl -s -u ":${pat}" \
    -H "Content-Type: application/json" \
    "${ORG_URL}/${PROJECT}/_apis/${path}&api-version=7.1" 2>/dev/null
}

# ── Pull: download work items to local backlog ──
do_pull() {
  echo "Pulling from Azure DevOps: ${PROJECT}..."
  local wiql='{"query":"SELECT [System.Id],[System.Title],[System.State] FROM WorkItems WHERE [System.WorkItemType] = '\''Product Backlog Item'\'' ORDER BY [System.CreatedDate] DESC"}'
  local response
  response=$(curl -s -u ":$(cat "$PAT_FILE")" \
    -H "Content-Type: application/json" \
    -d "$wiql" \
    "${ORG_URL}/${PROJECT}/_apis/wit/wiql?api-version=7.1" 2>/dev/null)

  local count
  count=$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('workItems',[])))" 2>/dev/null || echo "0")
  echo "Found $count work items in Azure DevOps"
  echo "Pull complete. Items would be merged into: $BACKLOG/pbi/"
  sync_log "pull" "$PROVIDER" "all" "found_${count}"
}

# ── Push: upload local PBIs to Azure DevOps ──
do_push() {
  echo "Push to Azure DevOps: ${PROJECT}..."
  local pushed=0
  for f in "$BACKLOG"/pbi/PBI-*.md; do
    [ -f "$f" ] || continue
    local az_id; az_id=$(get_pbi_field "$f" "azure_devops_id")
    local title; title=$(get_pbi_field "$f" "title")
    local pbi_id; pbi_id=$(get_pbi_field "$f" "id")
    if [ -z "$az_id" ]; then
      echo "  NEW: $pbi_id — $title (would create in Azure DevOps)"
      pushed=$((pushed + 1))
    else
      echo "  SYNC: $pbi_id — $title (AB#${az_id})"
    fi
    sync_log "push" "$PROVIDER" "$pbi_id" "ok"
  done
  echo "Push complete. $pushed new items to create."
}

# ── Diff: show differences without applying ──
do_diff() {
  echo "Diff: local backlog vs Azure DevOps (${PROJECT})"
  echo ""
  local local_count=0
  for f in "$BACKLOG"/pbi/PBI-*.md; do
    [ -f "$f" ] || continue
    local_count=$((local_count + 1))
  done
  echo "Local PBIs: $local_count"
  echo "Remote: (requires API call — use 'pull' to fetch)"
  echo ""
  echo "| PBI | Azure DevOps ID | Status |"
  echo "|-----|-----------------|--------|"
  for f in "$BACKLOG"/pbi/PBI-*.md; do
    [ -f "$f" ] || continue
    local pbi_id az_id
    pbi_id=$(get_pbi_field "$f" "id")
    az_id=$(get_pbi_field "$f" "azure_devops_id")
    if [ -z "$az_id" ]; then
      echo "| $pbi_id | — | local_only |"
    else
      echo "| $pbi_id | AB#$az_id | synced |"
    fi
  done
}

validate
case "${ACTION:-diff}" in
  pull) do_pull ;;
  push) do_push ;;
  diff) do_diff ;;
  *) echo "Usage: $0 <pull|push|diff> --project NAME" >&2; exit 1 ;;
esac
