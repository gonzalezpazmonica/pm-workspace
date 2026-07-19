#!/usr/bin/env bash
# veto-check.sh — SE-268 S1: Query veto bus before executing an action.
# Usage: veto-check.sh <action> [--socket /tmp/savia-veto.sock | --host 127.0.0.1 --port 9090]
# Exit codes: 0=allowed, 1=blocked, 2=error/bus unreachable (fail-closed)

set -euo pipefail

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "ERROR: missing action argument" >&2
  echo "Usage: veto-check.sh <action> [--socket PATH | --host H --port P]" >&2
  exit 2
fi

SOCKET="${VETO_BUS_SOCKET:-/tmp/savia-veto.sock}"
HOST="${VETO_BUS_HOST:-}"
PORT="${VETO_BUS_PORT:-9090}"

# Parse optional args
shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --socket) SOCKET="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Build curl command
ENCODED_ACTION=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${ACTION//\'/\'\\\'\'}'))")
if [[ -n "$HOST" ]]; then
  # TCP mode
  RESPONSE=$(curl -s --max-time 2 "${HOST}:${PORT}/check?q=${ENCODED_ACTION}" 2>/dev/null) || {
    echo '{"allowed":false,"blocked_by":[{"reason":"veto-bus-unreachable (fail-closed)"}]}'
    echo "BLOCKED: veto bus unreachable at ${HOST}:${PORT}" >&2
    exit 2
  }
else
  # Unix socket mode
  RESPONSE=$(curl -s --max-time 2 --unix-socket "$SOCKET" "http://localhost/check?q=${ENCODED_ACTION}" 2>/dev/null) || {
    echo '{"allowed":false,"blocked_by":[{"reason":"veto-bus-unreachable (fail-closed)"}]}'
    echo "BLOCKED: veto bus unreachable at ${SOCKET}" >&2
    exit 2
  }
fi

ALLOWED=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('allowed',False))" 2>/dev/null || echo "False")

if [[ "$ALLOWED" == "True" ]]; then
  echo "$RESPONSE"
  exit 0
else
  echo "$RESPONSE"
  echo "VETOED: ${ACTION}" >&2
  echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for v in d.get('blocked_by', []):
    print(f\"  {v.get('id','?')}: {v.get('reason','')}\")" 2>/dev/null
  exit 1
fi
