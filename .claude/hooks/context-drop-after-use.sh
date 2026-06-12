#!/usr/bin/env bash
set -uo pipefail
# context-drop-after-use.sh — SE-221 Slice 2 — Drop-After-Use hook
# PostToolUse hook para Read/WebFetch/Bash: si el output supera umbral,
# decide KEEP/STUB/DROP via context-drop-after-use.sh script.
# Si STUB, reescribe el output a un stub compacto.
#
# Spec: docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md (AC-07, AC-08, AC-09)
# Inspiracion: Context-Minimization (Beurer-Kellner 2025).
#
# Audit: cada decision se loggea en output/context-drop-audit.jsonl.

# Resolucion robusta del workspace
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAVIA_ENV="${SCRIPT_DIR}/../../scripts/savia-env.sh"
if [[ -f "$SAVIA_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$SAVIA_ENV" 2>/dev/null || true
fi
PHYSICAL_WS="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKSPACE="${SAVIA_WORKSPACE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DROP_SCRIPT="${PHYSICAL_WS}/scripts/context-drop-after-use.sh"

MIN_LINES="${CONTEXT_DROP_MIN_LINES:-500}"
AUDIT_LOG="${WORKSPACE}/output/context-drop-audit.jsonl"

# Leer stdin con timeout
INPUT=""
if [[ ! -t 0 ]]; then
  if command -v timeout >/dev/null 2>&1 && timeout --version >/dev/null 2>&1; then
    INPUT=$(timeout 3 cat 2>/dev/null) || true
  else
    INPUT=$(cat 2>/dev/null) || true
  fi
fi

[[ -z "$INPUT" ]] && exit 0

passthrough() {
  printf '%s' "$INPUT"
  exit 0
}

# jq disponible?
if ! command -v jq >/dev/null 2>&1; then
  passthrough
fi

# Solo procesamos JSON valido con tool_name
if ! printf '%s' "$INPUT" | jq -e 'type == "object" and has("tool_name")' >/dev/null 2>&1; then
  passthrough
fi

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
NEXT_TASK="${CONTEXT_DROP_NEXT_TASK:-}"

# Tools que procesamos
case "$TOOL_NAME" in
  Read|WebFetch|Bash) ;;
  *) passthrough ;;
esac

# Resolver path segun tool
FILE_PATH=""
case "$TOOL_NAME" in
  Read)
    FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
    ;;
  WebFetch)
    FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.url // empty' 2>/dev/null || echo "")
    ;;
  Bash)
    # Bash no tiene path canonico; usamos un placeholder generico que el
    # decision engine clasificara como sandbox (ver mapeo abajo)
    FILE_PATH="/tmp/opencode/bash-output.txt"
    ;;
esac

[[ -z "$FILE_PATH" ]] && passthrough

# Sandbox exento
case "$FILE_PATH" in
  /tmp/opencode/*)
    # Solo Bash usa esto; pasamos sin alterar
    [[ "$TOOL_NAME" == "Bash" ]] && passthrough
    ;;
esac

TOOL_OUTPUT=$(printf '%s' "$INPUT" | jq -r '.tool_response.output // .tool_response.content // empty' 2>/dev/null || echo "")
[[ -z "$TOOL_OUTPUT" ]] && passthrough

# Calcular lineas
LINE_COUNT=$(printf '%s' "$TOOL_OUTPUT" | wc -l 2>/dev/null || echo 0)
LINE_COUNT="${LINE_COUNT// /}"

# Bajo umbral: passthrough
if [[ "$LINE_COUNT" -lt "$MIN_LINES" ]]; then
  passthrough
fi

# Si ya es un stub, no re-stubbeamos (idempotencia)
if printf '%s' "$TOOL_OUTPUT" | head -1 | grep -q '^<stub origin='; then
  passthrough
fi

# Decidir veredicto
VERDICT_JSON=""
if [[ -x "$DROP_SCRIPT" ]]; then
  if [[ -n "$NEXT_TASK" ]]; then
    VERDICT_JSON=$(bash "$DROP_SCRIPT" --json --path "$FILE_PATH" --next-task "$NEXT_TASK" 2>/dev/null || echo '')
  else
    VERDICT_JSON=$(bash "$DROP_SCRIPT" --json --path "$FILE_PATH" --next-task "" 2>/dev/null || echo '')
  fi
fi

# Sin veredicto valido: passthrough
if [[ -z "$VERDICT_JSON" ]] || ! echo "$VERDICT_JSON" | jq -e '.verdict' >/dev/null 2>&1; then
  passthrough
fi

VERDICT=$(echo "$VERDICT_JSON" | jq -r '.verdict')
TIER=$(echo "$VERDICT_JSON" | jq -r '.tier')
ABSTRACT=$(echo "$VERDICT_JSON" | jq -r '.abstract // ""')
REASON=$(echo "$VERDICT_JSON" | jq -r '.reason // ""')

# Estimacion tokens ahorrados
ORIG_BYTES=$(printf '%s' "$TOOL_OUTPUT" | wc -c 2>/dev/null || echo 0)
ORIG_BYTES="${ORIG_BYTES// /}"
TOKENS_SAVED=0

# Audit log helper
audit_log() {
  local saved="$1"
  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || true
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
  local task_excerpt="${NEXT_TASK:0:80}"
  printf '{"ts":"%s","tool":"%s","path":"%s","tier":"%s","verdict":"%s","reason":"%s","next_task_excerpt":%s,"tokens_saved_est":%d}\n' \
    "$ts" "$TOOL_NAME" "$FILE_PATH" "$TIER" "$VERDICT" "$REASON" \
    "$(printf '%s' "$task_excerpt" | jq -Rs .)" \
    "$saved" >> "$AUDIT_LOG" 2>/dev/null || true
}

case "$VERDICT" in
  KEEP)
    audit_log 0
    passthrough
    ;;
  DROP)
    # Reemplaza por stub minimo
    TOKENS_SAVED=$(( ORIG_BYTES / 4 ))
    audit_log "$TOKENS_SAVED"
    NEW_OUTPUT="<stub origin=\"$FILE_PATH\" tier=\"$TIER\" verdict=\"DROP\" reason=\"$REASON\"/>"
    printf '%s' "$INPUT" | jq --arg new "$NEW_OUTPUT" '
      if .tool_response.output then .tool_response.output = $new
      elif .tool_response.content then .tool_response.content = $new
      else .tool_response = (.tool_response // {}) | .tool_response.output = $new
      end
    ' 2>/dev/null || passthrough
    ;;
  STUB)
    TOKENS_SAVED=$(( (ORIG_BYTES - ${#ABSTRACT} - 200) / 4 ))
    [[ "$TOKENS_SAVED" -lt 0 ]] && TOKENS_SAVED=0
    audit_log "$TOKENS_SAVED"
    NEW_OUTPUT="<stub origin=\"$FILE_PATH\" tier=\"$TIER\" full-content-at=\"$FILE_PATH\" abstract=\"$ABSTRACT\"/>"
    printf '%s' "$INPUT" | jq --arg new "$NEW_OUTPUT" '
      if .tool_response.output then .tool_response.output = $new
      elif .tool_response.content then .tool_response.content = $new
      else .tool_response = (.tool_response // {}) | .tool_response.output = $new
      end
    ' 2>/dev/null || passthrough
    ;;
  *)
    passthrough
    ;;
esac

exit 0
