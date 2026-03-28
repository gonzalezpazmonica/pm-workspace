#!/usr/bin/env bash
set -uo pipefail
# NOTE: -e omitted intentionally — grep returns 1 on no-match which would
# abort the script. All error paths are guarded explicitly with || or if/fi.
# data-sovereignty-audit.sh — PostToolUse hook (async)
# Profile tier: security

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "security"
fi

# Desactivar en entornos sin proyectos privados
[[ "${SAVIA_SHIELD_ENABLED:-true}" == "false" ]] && exit 0
# Capa 3: Verifica post-escritura que no se colo dato sensible en N1
# [FIX H1] Scans FULL file on disk, not truncated content

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
AUDIT_LOG="$PROJECT_DIR/output/data-sovereignty-audit.jsonl"
mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null

iso_ts() { date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -Iseconds; }

# Leer input del hook
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

FILE_PATH=""
if [[ -n "$INPUT" ]]; then
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null) || FILE_PATH=""
fi

# SEC-019: Log if input was empty (possible timeout)
if [[ -z "$FILE_PATH" ]]; then
  [[ -z "$INPUT" ]] && [[ -d "$(dirname "$AUDIT_LOG")" ]] && \n    printf '{"ts":"%s","layer":0,"verdict":"TIMEOUT_SKIP"}
' "$(iso_ts)" >> "$AUDIT_LOG" 2>/dev/null
  rm -f "$NORM_FILE" 2>/dev/null
exit 0
fi
[[ ! -f "$FILE_PATH" ]] && exit 0

# Only audit public (N1) files
is_public() {
  local f="$1"
  [[ "$f" == *"/projects/"* ]] && return 1
  [[ "$f" == *".local."* ]] && return 1
  [[ "$f" == *"/output/"* ]] && return 1
  [[ "$f" == *"private-agent-memory"* ]] && return 1
  [[ "$f" == *"config.local"* ]] && return 1
  [[ "$f" == *"/.savia/"* ]] && return 1
  [[ "$f" == *"/.claude/sessions/"* ]] && return 1
  [[ "$f" == *"settings.local.json"* ]] && return 1
  return 0
}

if ! is_public "$FILE_PATH"; then
  exit 0
fi

# Skip security doc files (same narrow whitelist as gate)
# SEC-006 FIX: Unicode NFKC normalization for full-file scan
normalize_file() {
  python3 -c "
import sys, unicodedata
text = sys.stdin.read()
print(unicodedata.normalize('NFKC', text))
" 2>/dev/null
}

case "$FILE_PATH" in
  *data-sovereignty*|*ollama-classify*|*test-data-sovereignty*) exit 0 ;;
esac

# [FIX H1] Scan FULL file on disk — not truncated
# VULN-007 FIX: Create normalized temp file for full-file scan
NORM_FILE=$(mktemp 2>/dev/null || echo "/tmp/shield-audit-$$")
if command -v python3 >/dev/null 2>&1; then
  PYTHONUTF8=1 python3 -c "import sys,unicodedata; print(unicodedata.normalize('NFKC',sys.stdin.read()))" < "$FILE_PATH" > "$NORM_FILE" 2>/dev/null || cp "$FILE_PATH" "$NORM_FILE"
else
  cp "$FILE_PATH" "$NORM_FILE"
fi

LEAK=""
if grep -qiE "(jdbc:|mongodb[+]srv://|Server=.*Password=)" "$NORM_FILE" 2>/dev/null; then
  LEAK="connection_string_in_public_file"
elif grep -qE "AKIA[0-9A-Z]{16}" "$NORM_FILE" 2>/dev/null; then
  LEAK="aws_key_in_public_file"
elif grep -qE "(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82,})" "$NORM_FILE" 2>/dev/null; then
  LEAK="github_token_in_public_file"
elif grep -qE "sk-[A-Za-z0-9]{20,}" "$NORM_FILE" 2>/dev/null; then
  LEAK="openai_key_in_public_file"
elif grep -qiE -- "-----BEGIN.*PRIVATE KEY-----" "$NORM_FILE" 2>/dev/null; then
  LEAK="private_key_in_public_file"
elif grep -qE "(192[.]168[.][0-9]+[.][0-9]+|10[.][0-9]+[.][0-9]+[.][0-9]+|172[.](1[6-9]|2[0-9]|3[01])[.][0-9]+[.][0-9]+)" "$NORM_FILE" 2>/dev/null; then
  LEAK="internal_ip_in_public_file"
fi

if [[ -n "$LEAK" ]]; then
  jq -nc --arg ts "$(iso_ts)" --arg file "$FILE_PATH" \
    --arg verdict "LEAK_DETECTED" --arg detail "$LEAK" \
    '{ts:$ts,layer:3,file:$file,verdict:$verdict,detail:$detail}' \
    >> "$AUDIT_LOG" 2>/dev/null
  echo "ALERTA [Capa 3]: Posible fuga en $FILE_PATH ($LEAK)" >&2
  echo "Revisa el fichero y elimina el dato sensible antes de commit." >&2
fi

exit 0
