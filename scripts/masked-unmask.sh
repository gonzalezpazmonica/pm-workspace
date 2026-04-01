#!/usr/bin/env bash
# masked-unmask.sh — Unmask a Claude response back to real entities
# Usage: echo "masked response" | masked-unmask.sh
# Output: unmasked text on stdout
set -uo pipefail

SHIELD_URL="${SHIELD_URL:-http://127.0.0.1:8444}"
SHIELD_TOKEN=""
[[ -f "$HOME/.savia/shield-token" ]] && SHIELD_TOKEN=$(cat "$HOME/.savia/shield-token" 2>/dev/null)
TOKEN_HEADER=""
[[ -n "$SHIELD_TOKEN" ]] && TOKEN_HEADER="-H X-Shield-Token:$SHIELD_TOKEN"

INPUT_TEXT=""
if [[ ! -t 0 ]]; then
  INPUT_TEXT=$(cat)
fi

if [[ -z "$INPUT_TEXT" ]]; then
  echo "ERROR: no input to unmask." >&2
  exit 1
fi

if ! curl -sf --max-time 2 "$SHIELD_URL/health" >/dev/null 2>&1; then
  echo "ERROR: Shield daemon not running at $SHIELD_URL" >&2
  exit 1
fi

ESCAPED=$(printf '%s' "$INPUT_TEXT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null)
RESULT=$(curl -s --max-time 30 -X POST "$SHIELD_URL/unmask" \
  -H "Content-Type: application/json" $TOKEN_HEADER \
  -d "{\"text\":$ESCAPED}" 2>/dev/null)

UNMASKED=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['unmasked'])" 2>/dev/null)

if [[ -z "$UNMASKED" ]]; then
  echo "ERROR: unmask failed" >&2
  exit 1
fi

echo "$UNMASKED"
