#!/usr/bin/env bash
set -uo pipefail
# NOTE: -e omitted intentionally — grep returns 1 on no-match which would
# abort the script. All error paths are guarded explicitly with || or if/fi.
# data-sovereignty-gate.sh — PreToolUse hook (Edit|Write)
# Capa 1: regex determinista + Capa 2: Ollama local si ambiguo
# Exit 0 = permitir, Exit 2 = bloquear
# AUDITABILITY: every decision logged to JSONL with JSON-safe escaping

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
AUDIT_LOG="$PROJECT_DIR/output/data-sovereignty-audit.jsonl"
mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null

iso_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -Iseconds; }

# [FIX C4] JSON-safe audit logging via jq
log_audit() {
  local layer="$1" file="$2" verdict="$3" detail="${4:-}"
  jq -nc --arg ts "$(iso_ts)" --argjson layer "$layer" \
    --arg file "$file" --arg verdict "$verdict" --arg detail "$detail" \
    '{ts:$ts,layer:$layer,file:$file,verdict:$verdict,detail:$detail}' \
    >> "$AUDIT_LOG" 2>/dev/null || \
  printf '{"ts":"%s","layer":%s,"verdict":"%s"}\n' "$(iso_ts)" "$layer" "$verdict" \
    >> "$AUDIT_LOG" 2>/dev/null
}

# Leer input del hook (JSON en stdin)
INPUT=""
# Portable stdin read
INPUT=""
if [[ ! -t 0 ]]; then
  if command -v timeout >/dev/null 2>&1 && timeout --version >/dev/null 2>&1; then
    INPUT=$(timeout 3 cat 2>/dev/null) || true
  else
    INPUT=$(cat 2>/dev/null) || true
  fi
fi

# Extraer file_path y contenido via jq (optimized)
FILE_PATH=""
CONTENT=""
if [[ -n "$INPUT" ]]; then
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null) || FILE_PATH=""
  CONTENT=$(printf '%s' "$INPUT" | jq -r '(.tool_input.content // .tool_input.new_string // "")[:20000]' 2>/dev/null) || CONTENT=""
fi

# SEC-006 FIX: Unicode NFKC normalization (defeats homoglyph bypass)
if [[ -n "$CONTENT" ]] && command -v python3 >/dev/null 2>&1; then
  CONTENT=$(printf '%s' "$CONTENT" | PYTHONUTF8=1 python3 -c "
import sys, unicodedata
sys.stdin.reconfigure(encoding='utf-8', errors='replace')
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
text = sys.stdin.read()
print(unicodedata.normalize('NFKC', text))
" 2>/dev/null) || true
fi

# SEC-019: Log if input was empty (possible timeout)
if [[ -z "$FILE_PATH" ]]; then
  [[ -z "$INPUT" ]] && [[ -d "$(dirname "$AUDIT_LOG")" ]] && \n    printf '{"ts":"%s","layer":0,"verdict":"TIMEOUT_SKIP"}
' "$(iso_ts)" >> "$AUDIT_LOG" 2>/dev/null
  exit 0
fi

# [FIX C3] Classify destination — .claude/ subdirs are PUBLIC except specific ones
is_public_destination() {
  local f="$1"
  [[ "$f" == *"/projects/"* ]] && return 1
  [[ "$f" == *".local."* ]] && return 1
  [[ "$f" == *"/output/"* ]] && return 1
  [[ "$f" == *"private-agent-memory"* ]] && return 1
  [[ "$f" == *"config.local"* ]] && return 1
  [[ "$f" == *"/.savia/"* ]] && return 1
  [[ "$f" == *"/.claude/sessions/"* ]] && return 1
  [[ "$f" == *"settings.local.json"* ]] && return 1
  # .claude/rules/, .claude/commands/, .claude/hooks/ ARE public (git-tracked)
  return 0
}

if ! is_public_destination "$FILE_PATH"; then
  exit 0
fi

# [FIX C2] Narrow whitelist — only specific data-sovereignty files, NOT directories
is_security_doc() {
  local f="$1"
  [[ "$f" == *"data-sovereignty-gate"* ]] && return 0
  [[ "$f" == *"data-sovereignty-audit"* ]] && return 0
  [[ "$f" == *"data-sovereignty.md"* ]] && return 0
  [[ "$f" == *"data-sovereignty-architecture"* ]] && return 0
  [[ "$f" == *"data-sovereignty-operations"* ]] && return 0
  [[ "$f" == *"data-sovereignty-auditability"* ]] && return 0
  [[ "$f" == *"ollama-classify.sh"* ]] && return 0
  [[ "$f" == *"test-data-sovereignty"* ]] && return 0
  return 1
}

if is_security_doc "$FILE_PATH"; then
  log_audit 1 "$FILE_PATH" "WHITELISTED" "security_doc"
  exit 0
fi

# --- CAPA 1: Regex determinista ---
CONFIDENTIAL_HIT=""

# [FIX C1] High-confidence patterns ALWAYS checked — no doc-word bypass
# Credentials and connection strings are NEVER acceptable in public files
if echo "$CONTENT" | grep -qiE "(jdbc:|mongodb[+]srv://|Server=.*Password=)"; then
  CONFIDENTIAL_HIT="connection_string"
elif echo "$CONTENT" | grep -qE "AKIA[0-9A-Z]{16}"; then
  CONFIDENTIAL_HIT="aws_key"
elif echo "$CONTENT" | grep -qE "(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82,})"; then
  CONFIDENTIAL_HIT="github_token"
elif echo "$CONTENT" | grep -qE "sk-(proj-)?[A-Za-z0-9]{32,}"; then
  CONFIDENTIAL_HIT="openai_key"
elif echo "$CONTENT" | grep -qiE "sv=20[0-9]{2}-"; then
  CONFIDENTIAL_HIT="azure_sas_token"
elif echo "$CONTENT" | grep -qE "AIza[0-9A-Za-z_-]{35}"; then
  CONFIDENTIAL_HIT="google_api_key"
elif echo "$CONTENT" | grep -qiE -- "-----BEGIN.*PRIVATE KEY-----"; then
  CONFIDENTIAL_HIT="private_key"
fi

# Base64 detection: decode suspicious base64 blobs and re-scan
if [[ -z "$CONFIDENTIAL_HIT" ]]; then
  B64_BLOBS=$(echo "$CONTENT" | grep -oE '[A-Za-z0-9+/]{40,200}={0,2}' 2>/dev/null | head -20)
  if [[ -n "$B64_BLOBS" ]]; then
    DECODED=$(echo "$B64_BLOBS" | while IFS= read -r blob; do
      echo "$blob" | base64 -d 2>/dev/null || true
    done)
    if [[ -n "$DECODED" ]]; then
      if echo "$DECODED" | grep -qiE "(jdbc:|Server=.*Password=|AKIA[0-9A-Z]{16}|ghp_|sk-(proj-)?[A-Za-z0-9]{32,}|-----BEGIN.*KEY)"; then
        CONFIDENTIAL_HIT="base64_encoded_secret"
      fi
    fi
  fi
fi

# [FIX H3] Lower-confidence patterns — skip only if CLEARLY documentation
if [[ -z "$CONFIDENTIAL_HIT" ]]; then
  DOC_WORDS=$(echo "$CONTENT" | grep -ciE "(example|placeholder|template)" 2>/dev/null || true)
  DOC_WORDS="${DOC_WORDS:-0}"
  if [[ "$DOC_WORDS" -eq 0 ]]; then
    if echo "$CONTENT" | grep -qE "(192[.]168[.][0-9]+[.][0-9]+|10[.][0-9]+[.][0-9]+[.][0-9]+|172[.](1[6-9]|2[0-9]|3[01])[.][0-9]+[.][0-9]+)"; then
      CONFIDENTIAL_HIT="internal_ip"
    fi
  fi
fi

if [[ -n "$CONFIDENTIAL_HIT" ]]; then
  log_audit 1 "$FILE_PATH" "BLOCKED" "$CONFIDENTIAL_HIT"
  echo "BLOQUEADO [Capa 1]: Dato confidencial detectado ($CONFIDENTIAL_HIT) en destino publico: $FILE_PATH" >&2
  echo "Mueve este contenido a un fichero N2-N4 (projects/, config.local/, .local.md)" >&2
  exit 2
fi

# --- SEC-005 FIX: Cross-write scan (split-write defense) ---
# If the file already exists on disk, scan COMBINED content (existing + new)
if [[ -z "$CONFIDENTIAL_HIT" ]] && [[ -f "$FILE_PATH" ]]; then
  EXISTING=$(head -c 20000 "$FILE_PATH" 2>/dev/null || true)
  if [[ -n "$EXISTING" ]]; then
    COMBINED="${EXISTING}${CONTENT}"
    if echo "$COMBINED" | grep -qiE "(jdbc:|mongodb[+]srv://|Server=.*Password=)"; then
      CONFIDENTIAL_HIT="split_write_connection_string"
    elif echo "$COMBINED" | grep -qE "AKIA[0-9A-Z]{16}"; then
      CONFIDENTIAL_HIT="split_write_aws_key"
    elif echo "$COMBINED" | grep -qE "(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82,})"; then
      CONFIDENTIAL_HIT="split_write_github_token"
    fi
    if [[ -n "$CONFIDENTIAL_HIT" ]]; then
      log_audit 1 "$FILE_PATH" "BLOCKED" "$CONFIDENTIAL_HIT"
      echo "BLOQUEADO [Capa 1 cross-write]: Dato confidencial detectado al combinar con contenido existente ($CONFIDENTIAL_HIT): $FILE_PATH" >&2
      exit 2
    fi
  fi
fi

# --- CAPA 2: Ollama local (solo si hay contenido sustancial) ---
if [[ ${#CONTENT} -lt 50 ]]; then
  exit 0
fi

CLASSIFY_SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/ollama-classify.sh"
if [[ -x "$CLASSIFY_SCRIPT" ]]; then
  VERDICT=$(echo "$CONTENT" | bash "$CLASSIFY_SCRIPT" 2>/dev/null) || VERDICT="UNAVAILABLE"
  case "$VERDICT" in
    CONFIDENTIAL)
      log_audit 2 "$FILE_PATH" "BLOCKED" "ollama_confidential"
      echo "BLOQUEADO [Capa 2]: LLM local clasifico contenido como CONFIDENCIAL en: $FILE_PATH" >&2
      exit 2
      ;;
    AMBIGUOUS)
      # [FIX C6] AMBIGUOUS = block (align with spec)
      log_audit 2 "$FILE_PATH" "BLOCKED" "ollama_ambiguous"
      echo "BLOQUEADO [Capa 2]: Clasificacion ambigua en: $FILE_PATH — revisa manualmente." >&2
      exit 2
      ;;
    UNAVAILABLE)
      log_audit 2 "$FILE_PATH" "SKIPPED" "ollama_unavailable"
      exit 0
      ;;
    PUBLIC)
      log_audit 2 "$FILE_PATH" "ALLOWED" "ollama_public"
      exit 0
      ;;
  esac
fi

exit 0
