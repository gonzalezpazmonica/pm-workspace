#!/usr/bin/env bash
# Detector: pr-stale-watch (SE-279)
# Checks for open PRs > 24h without review activity.
# Uses gh CLI. Output: JSON with triggered flag and stale PRs.

set -uo pipefail

HOURS_THRESHOLD="${STALE_PR_HOURS:-24}"

if ! command -v gh &>/dev/null; then
  echo '{"triggered":false,"reason":"gh CLI not available"}'
  exit 0
fi

# Check gh auth
if ! gh auth status &>/dev/null 2>&1; then
  echo '{"triggered":false,"reason":"gh not authenticated"}'
  exit 0
fi

# Get open PRs with review decision
PRS=$(gh pr list --state open --json number,title,createdAt,reviewDecision,author,url --limit 20 2>/dev/null || echo '[]')

# Filter stale PRs (> threshold hours, no approved review)
STALE=$(echo "$PRS" | python3 -c "
import sys, json
from datetime import datetime, timezone, timedelta

prs = json.load(sys.stdin)
threshold = datetime.now(timezone.utc) - timedelta(hours=$HOURS_THRESHOLD)
stale = []

for pr in prs:
    created = datetime.fromisoformat(pr['createdAt'].replace('Z', '+00:00'))
    if created < threshold and pr.get('reviewDecision') != 'APPROVED':
        stale.append({
            'number': pr['number'],
            'title': pr['title'],
            'author': pr.get('author', {}).get('login', 'unknown'),
            'created': pr['createdAt'],
            'review': pr.get('reviewDecision', 'UNKNOWN'),
            'url': pr.get('url', '')
        })

print(json.dumps(stale))
" 2>/dev/null || echo '[]')

COUNT=$(echo "$STALE" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

if [[ "$COUNT" -eq 0 ]]; then
  echo '{"triggered":false,"reason":"no stale PRs"}'
else
  echo "{\"triggered\":true,\"detector\":\"pr-stale-watch\",\"count\":$COUNT,\"items\":$STALE,\"summary\":\"$COUNT PR(s) open > ${HOURS_THRESHOLD}h without review\"}"
fi
