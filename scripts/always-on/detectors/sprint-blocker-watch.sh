#!/usr/bin/env bash
# Detector: sprint-blocker-watch (SE-279)
# Checks Azure DevOps for PBIs blocked > 48h without escalation.
# Output: JSON with triggered flag and blocked items.
# Uses PAT from $PAT_FILE (Rule #1).

set -uo pipefail

PAT_FILE="${PAT_FILE:-$HOME/.savia/pat}"
AZURE_ORG="${AZURE_DEVOPS_ORG_URL:-}"
PROJECT="${AZURE_DEVOPS_PROJECT:-}"
HOURS_THRESHOLD="${BLOCKER_HOURS_THRESHOLD:-48}"

# If no Azure DevOps config, skip gracefully
if [[ -z "$AZURE_ORG" ]] || [[ -z "$PROJECT" ]]; then
  echo '{"triggered":false,"reason":"Azure DevOps not configured"}'
  exit 0
fi

PAT=$(cat "$PAT_FILE" 2>/dev/null || echo "")
if [[ -z "$PAT" ]]; then
  echo '{"triggered":false,"reason":"PAT not available"}'
  exit 0
fi

# WIQL: find blocked PBIs (state = blocked/impeded) older than threshold
WIQL="SELECT [System.Id],[System.Title],[System.AssignedTo],[Microsoft.VSTS.Common.StateChangeDate]
FROM WorkItems
WHERE [System.TeamProject] = '$PROJECT'
AND [System.State] IN ('Blocked','Impeded','Bloqueado')
AND [System.ChangedDate] < @Today - 2
ORDER BY [System.ChangedDate]"

RESPONSE=$(curl -s -u ":${PAT}" \
  "${AZURE_ORG}/${PROJECT}/_apis/wit/wiql?api-version=7.1" \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"$WIQL\"}" 2>/dev/null || echo '{}')

WORK_ITEMS=$(echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
items = d.get('workItems', [])
result = []
for wi in items:
    result.append({'id': wi.get('id'), 'url': wi.get('url')})
print(json.dumps(result))
" 2>/dev/null || echo '[]')

COUNT=$(echo "$WORK_ITEMS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

if [[ "$COUNT" -eq 0 ]]; then
  echo '{"triggered":false,"reason":"no blocked items > 48h"}'
else
  echo "{\"triggered\":true,\"detector\":\"sprint-blocker-watch\",\"count\":$COUNT,\"items\":$WORK_ITEMS,\"summary\":\"$COUNT PBI(s) blocked > ${HOURS_THRESHOLD}h without escalation\"}"
fi
