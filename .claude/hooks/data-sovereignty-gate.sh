#!/usr/bin/env bash
# data-sovereignty-gate.sh — Savia Shield unified gate hook
# Single curl call to daemon /gate endpoint. All logic server-side.
# Fallback: if daemon down, inline regex (slow but functional).
# NOTE: -e omitted intentionally — grep returns 1 on no-match.
set -uo pipefail

SHIELD_PORT="${SAVIA_SHIELD_PORT:-8444}"
SHIELD_URL="http://127.0.0.1:${SHIELD_PORT}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
AUDIT_LOG="$PROJECT_DIR/output/data-sovereignty-audit.jsonl"
mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null

# Read hook input from stdin
INPUT=""
if [[ ! -t 0 ]]; then
  if command -v timeout >/dev/null 2>&1 && timeout --version >/dev/null 2>&1; then
    INPUT=$(timeout 3 cat 2>/dev/null) || true
  else
    INPUT=$(cat 2>/dev/null) || true
  fi
fi
[[ -z "$INPUT" ]] && exit 0

# Load auth token
SHIELD_TOKEN=""
[[ -f "$HOME/.savia/shield-token" ]] && SHIELD_TOKEN=$(cat "$HOME/.savia/shield-token" 2>/dev/null)
TOKEN_HEADER=""
[[ -n "$SHIELD_TOKEN" ]] && TOKEN_HEADER="-H X-Shield-Token:$SHIELD_TOKEN"

# Try daemon /gate (fast path: one HTTP call does everything)
if curl -sf --max-time 2 "$SHIELD_URL/health" >/dev/null 2>&1; then
  RESULT=$(curl -s --max-time 10 \
    -X POST "$SHIELD_URL/gate" \
    -H "Content-Type: application/json" \
    $TOKEN_HEADER \
    -d "$INPUT" 2>/dev/null)

  if [[ -n "$RESULT" ]]; then
    # Parse verdict with lightweight grep (no python3 needed)
    if echo "$RESULT" | grep -q '"BLOCK"'; then
      echo "$RESULT" | jq -r '.entities[]? | "  [\(.type)] \(.text)"' 2>/dev/null | head -5 >&2
      echo "BLOQUEADO [Savia Shield]: PII detectado en fichero publico" >&2
      # Log
      echo "$RESULT" | jq -c '. + {ts:now|todate,layer:"gate"}' >> "$AUDIT_LOG" 2>/dev/null
      exit 2
    fi
    exit 0
  fi
fi

# Fallback: daemon down — inline regex (slow but functional)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null) || exit 0
CONTENT=$(printf '%s' "$INPUT" | jq -r '(.tool_input.content // .tool_input.new_string // "")[:20000]' 2>/dev/null) || exit 0

[[ -z "$FILE_PATH" ]] && exit 0

# Skip private destinations
case "$FILE_PATH" in
  */projects/*|*.local.*|*/output/*|*private-agent-memory*|*/config.local/*|*/.savia/*|*/.claude/sessions/*|*settings.local.json*) exit 0 ;;
esac
case "$FILE_PATH" in
  *data-sovereignty*|*ollama-classify*|*shield-ner*|*savia-shield*|*sovereignty-mask*|*test-data-sovereignty*) exit 0 ;;
esac

# Inline regex fallback (no NER, no NFKC — daemon handles those)
if echo "$CONTENT" | grep -qiE "(jdbc:|mongodb[+]srv://|Server=.*Password=)"; then
  echo "BLOQUEADO [fallback]: connection_string en $FILE_PATH" >&2; exit 2
elif echo "$CONTENT" | grep -qE "AKIA[0-9A-Z]{16}"; then
  echo "BLOQUEADO [fallback]: aws_key en $FILE_PATH" >&2; exit 2
elif echo "$CONTENT" | grep -qE "(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82,})"; then
  echo "BLOQUEADO [fallback]: github_token en $FILE_PATH" >&2; exit 2
elif echo "$CONTENT" | grep -qE "sk-(proj-)?[A-Za-z0-9]{32,}"; then
  echo "BLOQUEADO [fallback]: openai_key en $FILE_PATH" >&2; exit 2
elif echo "$CONTENT" | grep -qiE -- "-----BEGIN.*PRIVATE KEY-----"; then
  echo "BLOQUEADO [fallback]: private_key en $FILE_PATH" >&2; exit 2
fi

exit 0
