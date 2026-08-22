#!/usr/bin/env bash
set -uo pipefail
# discovery-order-telemetry.sh — SE-336 S3: telemetría del orden de
# descubrimiento (SE-335) por turno.
#
# PostToolUse `.*` async (shadow). Registra por turno qué herramientas se
# usaron primero para resolver preguntas de conocimiento y si el orden
# respetó la regla: cúpulas → memoria → grafo de código → grep.
#
#   order_ok=true  → ningún grep/glob/read antes de la primera herramienta
#                    de conocimiento (vault_search|vault_read|vault_graph|
#                    memory-store recall|search_graph|trace_path|
#                    codegraph_explore) en un turno con pregunta.
#   order_ok=false → hubo grep/glob/read ANTES de la herramienta de conocimiento.
#   order_ok=na    → turno no-cognitivo (solo escritura/ejecución) — no penaliza.
#
# RN-04: guarda query_hash, nunca el prompt completo. Nunca bloquea (shadow).
# Master switch: SAVIA_DISCOVERY_TELEMETRY=off.
# Estado por sesión en TMPDIR: acumula la secuencia de tools del turno actual
# y consolida una línea JSONL por turno (al llegar la 1ª tool de conocimiento
# o al agotarse la ventana de 12 tools).

MASTER_SWITCH="${SAVIA_DISCOVERY_TELEMETRY:-on}"
LOG_DIR="${SAVIA_DISCOVERY_TELEMETRY_LOG_DIR:-$(pwd)/output/learning-loop}"
MAX_TOOLS="${SAVIA_DISCOVERY_TELEMETRY_MAX_TOOLS:-12}"

[[ "$MASTER_SWITCH" == "off" ]] && exit 0

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
[[ -z "$TOOL_NAME" ]] && exit 0

# prompt del turno (solo para hash — RN-04)
PROMPT_TEXT=$(echo "$INPUT" | jq -r '.prompt_text // .content // empty' 2>/dev/null | head -c 2000)

STATE_FILE="${TMPDIR:-/tmp}/discovery-order-${SESSION_ID}.state"

# ── Clasificación de herramienta ─────────────────────────────────────────────
is_knowledge_tool() {
  case "$1" in
    *vault_search*|*vault_read*|*vault_graph*|*vault_list*|*vault_domes*|\
    *memory-store*recall*|*memory-store.sh*|\
    *search_graph*|*trace_path*|*codegraph_explore*|*get_code_snippet*) return 0 ;;
    *) return 1 ;;
  esac
}
is_filesearch_tool() {
  case "$1" in
    grep|glob|read|find) return 0 ;;
    *) return 1 ;;
  esac
}
is_write_exec_tool() {
  case "$1" in
    edit|write|bash|bash-*|webfetch|task|todowrite) return 0 ;;
    *) return 1 ;;
  esac
}

# ── Estado del turno ─────────────────────────────────────────────────────────
SEQUENCE=""
COUNT=0
if [[ -f "$STATE_FILE" ]]; then
  SEQUENCE=$(head -1 "$STATE_FILE")
  COUNT=$(tail -1 "$STATE_FILE")
fi

# ventana: al superar MAX_TOOLS sin herramienta de conocimiento, consolida na
if (( COUNT >= MAX_TOOLS )); then
  SEQUENCE=""
  COUNT=0
fi

NEWSEQ="${SEQUENCE}${TOOL_NAME},"
SEQUENCE="$NEWSEQ"
COUNT=$((COUNT + 1))
printf '%s\n%s\n' "$SEQUENCE" "$COUNT" > "$STATE_FILE"

# ── Consolidación de línea por turno ─────────────────────────────────────────
emit() {
  local order_ok="$1"
  mkdir -p "$LOG_DIR"
  local qh
  qh=$(printf '%s' "$PROMPT_TEXT" | sha256sum | cut -c1-16)
  printf '{"ts":"%s","query_hash":"%s","first_tools":"%s","order_ok":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$qh" "${SEQUENCE%,}" "$order_ok" \
    >> "$LOG_DIR/discovery-order.jsonl"
  rm -f "$STATE_FILE"
}

if is_knowledge_tool "$TOOL_NAME"; then
  # ¿hubo filesearch antes en este turno?
  EARLY_FS=false
  IFS=',' read -ra TOOLS <<< "${SEQUENCE%,}"
  for t in "${TOOLS[@]}"; do
    [[ -z "$t" ]] && continue
    is_filesearch_tool "$t" && EARLY_FS=true && break
  done
  if [[ "$EARLY_FS" == "true" ]]; then
    emit "false"
  else
    emit "true"
  fi
  exit 0
fi

if is_filesearch_tool "$TOOL_NAME"; then
  # si el turno ya acumuló ≥3 filesearch sin knowledge, consolida false
  FS_COUNT=0
  IFS=',' read -ra TOOLS <<< "${SEQUENCE%,}"
  for t in "${TOOLS[@]}"; do
    [[ -z "$t" ]] && continue
    is_filesearch_tool "$t" && FS_COUNT=$((FS_COUNT+1))
  done
  if (( FS_COUNT >= 3 )); then
    emit "false"
  fi
  exit 0
fi

exit 0
