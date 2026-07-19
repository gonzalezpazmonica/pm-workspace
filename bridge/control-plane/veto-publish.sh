#!/usr/bin/env bash
# veto-publish.sh — SE-268 S1: Publish a veto to the control plane.
# Usage: veto-publish.sh --action "tool:Write:*" [--scope global|domain|instance|session]
#                        [--ttl SECONDS] [--reason "reason text"] [--domain NAME]
#                        [--socket PATH | --host H --port P]

set -euo pipefail

SOCKET="${VETO_BUS_SOCKET:-/tmp/savia-veto.sock}"
HOST="${VETO_BUS_HOST:-}"
PORT="${VETO_BUS_PORT:-9090}"
ACTION="*"
SCOPE="global"
TTL="null"
REASON=""
DOMAIN=""
INSTANCE=""
SESSION=""
SOURCE="human"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action) ACTION="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    --ttl) TTL="$2"; shift 2 ;;
    --reason) REASON="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --instance) INSTANCE="$2"; shift 2 ;;
    --session) SESSION="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --socket) SOCKET="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

JSON_BODY=$(python3 -c "
import json
print(json.dumps({
    'action': '${ACTION//\'/\'\\\'\'}',
    'scope': '$SCOPE',
    'ttl': $TTL,
    'reason': '${REASON//\'/\'\\\'\'}',
    'domain': '$DOMAIN',
    'instance': '$INSTANCE',
    'session': '$SESSION',
    'source': '$SOURCE'
}))
")

if [[ -n "$HOST" ]]; then
  RESPONSE=$(curl -s --max-time 2 -X POST "${HOST}:${PORT}/veto" \
    -H "Content-Type: application/json" -d "$JSON_BODY" 2>/dev/null) || {
      echo "ERROR: veto bus unreachable at ${HOST}:${PORT}" >&2
      exit 2
    }
else
  RESPONSE=$(curl -s --max-time 2 -X POST --unix-socket "$SOCKET" \
    "http://localhost/veto" \
    -H "Content-Type: application/json" -d "$JSON_BODY" 2>/dev/null) || {
      echo "ERROR: veto bus unreachable at ${SOCKET}" >&2
      exit 2
    }
fi

echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
