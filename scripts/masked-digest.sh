#!/usr/bin/env bash
# masked-digest.sh — Masked digestion pipeline
# Masks confidential text before processing, unmasks after.
# Usage: echo "text" | masked-digest.sh [--dry-run]
#   or:  masked-digest.sh --file <path> [--dry-run]
# Output: unmasked digest on stdout
# Requires: Shield daemon running on localhost:8444
set -uo pipefail

SHIELD_URL="${SHIELD_URL:-http://127.0.0.1:8444}"
SHIELD_TOKEN=""
[[ -f "$HOME/.savia/shield-token" ]] && SHIELD_TOKEN=$(cat "$HOME/.savia/shield-token" 2>/dev/null)
TOKEN_HEADER=""
[[ -n "$SHIELD_TOKEN" ]] && TOKEN_HEADER="-H X-Shield-Token:$SHIELD_TOKEN"

DRY_RUN=false
INPUT_FILE=""
INPUT_TEXT=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --file) INPUT_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Read input
if [[ -n "$INPUT_FILE" ]]; then
  [[ ! -f "$INPUT_FILE" ]] && echo "ERROR: file not found: $INPUT_FILE" >&2 && exit 1
  INPUT_TEXT=$(cat "$INPUT_FILE")
elif [[ ! -t 0 ]]; then
  INPUT_TEXT=$(cat)
fi

if [[ -z "$INPUT_TEXT" ]]; then
  echo "ERROR: no input. Use --file <path> or pipe text via stdin." >&2
  exit 1
fi

# Check daemon
if ! curl -sf --max-time 2 "$SHIELD_URL/health" >/dev/null 2>&1; then
  echo "ERROR: Shield daemon not running at $SHIELD_URL" >&2
  exit 1
fi

# Step 1: MASK
ESCAPED=$(printf '%s' "$INPUT_TEXT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null)
MASK_RESPONSE=$(curl -s --max-time 30 -X POST "$SHIELD_URL/mask" \
  -H "Content-Type: application/json" $TOKEN_HEADER \
  -d "{\"text\":$ESCAPED}" 2>/dev/null)

MASKED_TEXT=$(echo "$MASK_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['masked'])" 2>/dev/null)
WAS_CHANGED=$(echo "$MASK_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['changed'])" 2>/dev/null)

if [[ -z "$MASKED_TEXT" ]]; then
  echo "ERROR: masking failed" >&2
  exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== DRY RUN ==="
  echo "Changed: $WAS_CHANGED"
  echo "=== Masked text (this is what Claude would see) ==="
  echo "$MASKED_TEXT"
  exit 0
fi

# Step 2: output masked text for the caller to process with Claude
# The caller (agent or script) sends MASKED_TEXT to Claude and gets a response
# Then pipes the response back through unmask
echo "$MASKED_TEXT"
