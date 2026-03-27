#!/usr/bin/env bash
# shield-ner-hook.sh — Savia Shield Capa 1.5: NER via daemon (fast)
# Uses shield-ner-daemon.py HTTP API instead of cold-starting spaCy
# Exit 0 = clean/skip, Exit 2 = PII detected (block write)
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
NER_PORT="${SAVIA_NER_PORT:-8444}"
NER_URL="http://127.0.0.1:${NER_PORT}"

# Skip if daemon not running (graceful degradation)
if ! curl -sf --max-time 1 "$NER_URL/health" >/dev/null 2>&1; then
  exit 0
fi

# Read hook input
INPUT=""
if [[ ! -t 0 ]]; then
  if command -v timeout >/dev/null 2>&1 && timeout --version >/dev/null 2>&1; then
    INPUT=$(timeout 3 cat 2>/dev/null) || true
  else
    INPUT=$(cat 2>/dev/null) || true
  fi
fi
[[ -z "$INPUT" ]] && exit 0

# Extract file_path and content
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
CONTENT=$(printf '%s' "$INPUT" | jq -r '(.tool_input.content // .tool_input.new_string // "")[:5000]' 2>/dev/null) || exit 0

[[ -z "$FILE_PATH" ]] && exit 0
[[ ${#CONTENT} -lt 20 ]] && exit 0

# Only scan public destinations
case "$FILE_PATH" in
  */projects/*|*.local.*|*/output/*|*private-agent-memory*|*/config.local/*|*/.savia/*|*/.claude/sessions/*|*settings.local.json*) exit 0 ;;
esac
case "$FILE_PATH" in
  *data-sovereignty*|*ollama-classify*|*shield-ner*|*savia-shield*|*sovereignty-mask*|*test-data-sovereignty*) exit 0 ;;
esac

# Load auth token
SHIELD_TOKEN=""
[[ -f "$HOME/.savia/shield-token" ]] && SHIELD_TOKEN=$(cat "$HOME/.savia/shield-token" 2>/dev/null)
TOKEN_HEADER=""
[[ -n "$SHIELD_TOKEN" ]] && TOKEN_HEADER="-H X-Shield-Token:$SHIELD_TOKEN"

# Call NER daemon via HTTP (fast — model already in RAM)
ESCAPED=$(printf '%s' "$CONTENT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null)
RESULT=$(curl -sf --max-time 5 -X POST "$NER_URL/scan" $TOKEN_HEADER \
  -H "Content-Type: application/json" \
  -d "{\"text\":${ESCAPED},\"threshold\":0.7}" 2>/dev/null)

if [[ -z "$RESULT" ]]; then
  exit 0  # daemon didn't respond, degrade gracefully
fi

VERDICT=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('verdict','CLEAN'))" 2>/dev/null)

if [[ "$VERDICT" == "PII_DETECTED" ]]; then
  echo "BLOQUEADO [Capa 1.5 NER]: Entidades PII detectadas en: $FILE_PATH" >&2
  ENTITIES=$(echo "$RESULT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for e in d.get('entities',[]):
  if e['action']=='BLOCK':
    print(f\"  [{e['type']}] {e['text']} (score: {e['score']})\")
" 2>/dev/null)
  echo "$ENTITIES" >&2
  exit 2
fi

exit 0
