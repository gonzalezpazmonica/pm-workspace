#!/usr/bin/env bash
set -uo pipefail
# context-origin-stamp.sh — SE-221 Slice 1 — Context Origin Tagging hook
# PostToolUse hook para Read: prefija el output con bloque YAML ---origin
# que indica path, tier (N1..N5), loaded_at, size_tokens, hash.
#
# Spec: docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md (AC-02, AC-03)
# Inspiracion: Spotlighting (Hines et al. 2024) — origen explicito por diseno.
#
# Comportamiento:
# - Lee JSON de stdin (formato hook PostToolUse de Claude Code).
# - Solo aplica si tool=Read, output supera CONTEXT_ORIGIN_MIN_LINES (default 200).
# - Excluye sandbox /tmp/opencode/*.
# - Idempotente: si el bloque ---origin ya existe, no lo duplica.
# - NO modifica el contenido, solo prefija el bloque.
# - Fallback silencioso: cualquier error retorna stdin original (no rompe Read).

# Resolucion robusta del workspace
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAVIA_ENV="${SCRIPT_DIR}/../../scripts/savia-env.sh"
if [[ -f "$SAVIA_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$SAVIA_ENV" 2>/dev/null || true
fi
# WORKSPACE = workspace logico (puede ser override por test). El TAG_SCRIPT
# vive en el workspace fisico (donde esta el hook).
WORKSPACE="${SAVIA_WORKSPACE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
PHYSICAL_WS="$(cd "$SCRIPT_DIR/../.." && pwd)"
TAG_SCRIPT="${PHYSICAL_WS}/scripts/context-origin-tag.sh"

MIN_LINES="${CONTEXT_ORIGIN_MIN_LINES:-200}"

# Leer stdin (con timeout para evitar hangs)
INPUT=""
if [[ ! -t 0 ]]; then
  if command -v timeout >/dev/null 2>&1 && timeout --version >/dev/null 2>&1; then
    INPUT=$(timeout 3 cat 2>/dev/null) || true
  else
    INPUT=$(cat 2>/dev/null) || true
  fi
fi

# Sin input → exit silencioso (no rompe pipeline)
if [[ -z "$INPUT" ]]; then
  exit 0
fi

# Helper: emitir el input tal cual (passthrough seguro)
passthrough() {
  printf '%s' "$INPUT"
  exit 0
}

# Si jq no disponible → passthrough
if ! command -v jq >/dev/null 2>&1; then
  passthrough
fi

# Determinar formato: JSON hook (con tool_input) o texto plano (modo standalone test)
TOOL_NAME=""
FILE_PATH=""
TOOL_OUTPUT=""
IS_JSON=0

# JSON hook valido = objeto con .tool_name (no cualquier JSON valido como un numero)
if printf '%s' "$INPUT" | jq -e 'type == "object" and has("tool_name")' >/dev/null 2>&1; then
  IS_JSON=1
  TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
  TOOL_OUTPUT=$(printf '%s' "$INPUT" | jq -r '.tool_response.output // .tool_response.content // empty' 2>/dev/null || echo "")
fi

# Modo standalone (testing): si NO es JSON-hook y hay env var, tratamos input como output
if [[ "$IS_JSON" -eq 0 && -n "${CONTEXT_ORIGIN_TEST_PATH:-}" ]]; then
  TOOL_NAME="Read"
  FILE_PATH="$CONTEXT_ORIGIN_TEST_PATH"
  TOOL_OUTPUT="$INPUT"
fi

# Solo aplicamos a Read
if [[ "$TOOL_NAME" != "Read" ]]; then
  passthrough
fi

# Sin file_path no hay tagging posible
if [[ -z "$FILE_PATH" ]]; then
  passthrough
fi

# Sandbox exento
case "$FILE_PATH" in
  /tmp/opencode/*) passthrough ;;
esac

# Calcular numero de lineas del output
LINE_COUNT=0
if [[ -n "$TOOL_OUTPUT" ]]; then
  LINE_COUNT=$(printf '%s' "$TOOL_OUTPUT" | wc -l 2>/dev/null || echo 0)
  LINE_COUNT="${LINE_COUNT// /}"
fi

# Bajo umbral → passthrough (no pagamos coste)
if [[ "$LINE_COUNT" -lt "$MIN_LINES" ]]; then
  passthrough
fi

# Idempotencia: si ya hay bloque ---origin al inicio del output, passthrough
if printf '%s' "$TOOL_OUTPUT" | head -1 | grep -q '^---origin$'; then
  passthrough
fi

# Resolver tier
TIER="untrusted"
if [[ -x "$TAG_SCRIPT" ]]; then
  TIER=$(bash "$TAG_SCRIPT" "$FILE_PATH" 2>/dev/null || echo "untrusted")
fi

# Hash corto (sha256 primeros 8 hex)
HASH="unknown"
if [[ -f "$FILE_PATH" ]] && [[ -r "$FILE_PATH" ]]; then
  if command -v sha256sum >/dev/null 2>&1; then
    HASH=$(sha256sum "$FILE_PATH" 2>/dev/null | cut -c1-8)
  elif command -v shasum >/dev/null 2>&1; then
    HASH=$(shasum -a 256 "$FILE_PATH" 2>/dev/null | cut -c1-8)
  fi
fi

# Estimacion grosera de tokens: bytes/4
SIZE_BYTES=0
if [[ -n "$TOOL_OUTPUT" ]]; then
  SIZE_BYTES=$(printf '%s' "$TOOL_OUTPUT" | wc -c 2>/dev/null || echo 0)
  SIZE_BYTES="${SIZE_BYTES// /}"
fi
SIZE_TOKENS=$(( SIZE_BYTES / 4 ))

LOADED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")

# Construir bloque ---origin
ORIGIN_BLOCK=$(cat <<EOF
---origin
path: ${FILE_PATH}
tier: ${TIER}
loaded_at: ${LOADED_AT}
size_tokens: ${SIZE_TOKENS}
hash: sha256:${HASH}
---
EOF
)

# Reescribir el JSON con tool_response.output prefijado
# Si el input es JSON valido, mutamos; si no (modo standalone), prefijamos directamente
if [[ "$IS_JSON" -eq 1 ]]; then
  # JSON path
  NEW_OUTPUT="${ORIGIN_BLOCK}
${TOOL_OUTPUT}"
  printf '%s' "$INPUT" | jq --arg new "$NEW_OUTPUT" '
    if .tool_response.output then .tool_response.output = $new
    elif .tool_response.content then .tool_response.content = $new
    else .tool_response = (.tool_response // {}) | .tool_response.output = $new
    end
  ' 2>/dev/null || passthrough
else
  # Modo standalone (texto plano)
  printf '%s\n%s' "$ORIGIN_BLOCK" "$INPUT"
fi

exit 0
