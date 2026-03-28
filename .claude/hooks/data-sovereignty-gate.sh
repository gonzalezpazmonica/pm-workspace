#!/usr/bin/env bash
# data-sovereignty-gate.sh — Savia Shield unified gate hook (-e omitted: grep returns 1)
set -uo pipefail

# Desactivar en entornos sin proyectos privados
[[ "${SAVIA_SHIELD_ENABLED:-true}" == "false" ]] && exit 0

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
    if echo "$RESULT" | grep -q '"BLOCK"'; then
      echo "$RESULT" | jq -r '.entities[]? | "  [\(.type)] \(.text)"' 2>/dev/null | head -5 >&2
      echo "BLOQUEADO [Savia Shield]: PII detectado en fichero publico" >&2
      echo "$RESULT" | jq -c '. + {ts:now|todate,layer:"gate"}' >> "$AUDIT_LOG" 2>/dev/null
      exit 2
    fi
    exit 0
  fi
fi

# Fallback: daemon down — inline regex
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null) || exit 0
CONTENT=$(printf '%s' "$INPUT" | jq -r '(.tool_input.content // .tool_input.new_string // "")[:20000]' 2>/dev/null) || exit 0

[[ -z "$FILE_PATH" ]] && exit 0

# Normalize path (resolve ../ traversal)
NORM_PATH="$FILE_PATH"
if command -v python3 >/dev/null 2>&1; then
  NORM_PATH=$(python3 -c "import os,sys;print(os.path.normpath(sys.argv[1]))" "$FILE_PATH" 2>/dev/null) || NORM_PATH="$FILE_PATH"
fi

# Skip private destinations (use normalized path)
case "$NORM_PATH" in
  */projects/*|*.local.*|*/output/*|*private-agent-memory*|*/config.local/*|*/.savia/*|*/.claude/sessions/*|*settings.local.json*) exit 0 ;;
esac
# Whitelist specific sovereignty/shield files
case "$NORM_PATH" in
  *scripts/data-sovereignty*|*scripts/ollama-classify*|*scripts/shield-ner*|*scripts/savia-shield*|*scripts/sovereignty-mask*|*scripts/pre-commit-sovereignty*|*tests/test-data-sovereignty*) exit 0 ;;
  *hooks/data-sovereignty*|*hooks/ollama-classify*|*hooks/shield-ner*) exit 0 ;;
esac

# Helper: block and log
block_fallback() {
  local reason="$1"
  echo "BLOQUEADO [fallback]: ${reason} en $FILE_PATH" >&2
  printf '{"ts":"%s","layer":"fallback","verdict":"BLOCKED","reason":"%s","file":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")" "$reason" "$FILE_PATH" \
    >> "$AUDIT_LOG" 2>/dev/null
  exit 2
}

# NFKC normalize content if python3 available (catches fullwidth digits)
NORM_CONTENT="$CONTENT"
if command -v python3 >/dev/null 2>&1; then
  NORM_CONTENT=$(printf '%s' "$CONTENT" | python3 -c "import sys,unicodedata;print(unicodedata.normalize('NFKC',sys.stdin.read()))" 2>/dev/null) || NORM_CONTENT="$CONTENT"
fi

# Cross-write: if file exists, combine existing + new content for split detection
CROSSWRITE_PAT='Server=.*[Pp]assword=|[Pp]assword=.*Server='
if [[ -f "$FILE_PATH" ]]; then
  EXISTING=$(head -c 10000 "$FILE_PATH" 2>/dev/null) || true
  if [[ -n "$EXISTING" ]]; then
    COMBINED="${EXISTING} ${NORM_CONTENT}"
    if echo "$COMBINED" | grep -qiE "$CROSSWRITE_PAT"; then
      block_fallback "split_write"
    fi
  fi
fi

# Base64 decode check: find long base64 blobs and scan decoded content
if command -v base64 >/dev/null 2>&1; then
  B64_BLOBS=$(echo "$NORM_CONTENT" | grep -oE '[A-Za-z0-9+/]{40,}={0,2}' | head -3)
  for blob in $B64_BLOBS; do
    DECODED=$(echo "$blob" | base64 -d 2>/dev/null) || continue
    if echo "$DECODED" | grep -qiE "(jdbc:|mongodb|AKIA[0-9A-Z]{16})"; then
      block_fallback "base64_credential"
    fi
  done
fi

# Inline regex on normalized content
CRED_CONN='(jdbc:|mongodb[+]srv://)'
if echo "$NORM_CONTENT" | grep -qiE "$CRED_CONN"; then
  block_fallback "connection_string"
elif echo "$NORM_CONTENT" | grep -qiE "$CROSSWRITE_PAT"; then
  block_fallback "connection_string"
elif echo "$NORM_CONTENT" | grep -qE "AKIA[0-9A-Z]{16}"; then
  block_fallback "aws_key"
elif echo "$NORM_CONTENT" | grep -qE '(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82,})'; then
  block_fallback "github_token"
elif echo "$NORM_CONTENT" | grep -qE 'sk-(proj-)?[A-Za-z0-9]{32,}'; then
  block_fallback "openai_key"
elif echo "$NORM_CONTENT" | grep -qE 'sv=20[0-9]{2}-'; then
  block_fallback "azure_sas"
elif echo "$NORM_CONTENT" | grep -qiE -- '-----BEGIN.*PRIV[AEIOU]*TE KEY-----'; then
  block_fallback "private_key"
elif echo "$NORM_CONTENT" | grep -qE '(192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)'; then
  block_fallback "internal_ip"
fi

# Layer 2: Ollama classification for long content that passed regex
CLASSIFY="$PROJECT_DIR/scripts/ollama-classify.sh"
if [[ -x "$CLASSIFY" ]] && [[ ${#NORM_CONTENT} -gt 50 ]]; then
  VERDICT=$("$CLASSIFY" "$NORM_CONTENT" 2>/dev/null) || VERDICT="UNAVAILABLE"
  case "$VERDICT" in
    CONFIDENTIAL|AMBIGUOUS)
      block_fallback "ollama_${VERDICT,,}"
      ;;
    PUBLIC|UNAVAILABLE|*)
      : # allow
      ;;
  esac
fi

exit 0
