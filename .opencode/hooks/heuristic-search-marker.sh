#!/bin/bash
set -uo pipefail
# heuristic-search-marker.sh — SE-XXX PostToolUse hook
#
# Marca per-turn cuando el agente ha consultado un índice T1 de la heurística
# tier-based (members/, GLOSSARY.md, STAKEHOLDERS.md, INDEX.md, _HUB.md,
# .acm, .hcm, .afm, MEMORY.md) dentro de un proyecto.
#
# Consumidor: .opencode/hooks/heuristic-search-enforcement.sh (PreToolUse Bash)
#
# Input: JSON con tool_name=Read + tool_input.file_path via stdin
# Exit: siempre 0 (no-op si no aplica)
#
# Ref: docs/rules/domain/heuristic-search.md

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"
fi

if ! command -v jq &>/dev/null; then exit 0; fi

INPUT=""
if INPUT=$(timeout 3 cat 2>/dev/null); then :; fi
[[ -z "$INPUT" ]] && exit 0

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[[ "$TOOL_NAME" != "Read" && "$TOOL_NAME" != "Grep" && "$TOOL_NAME" != "Glob" ]] && exit 0

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0

# Solo si esta dentro de projects/
case "$FILE_PATH" in
  */projects/*) ;;
  *) exit 0 ;;
esac

PROJECT_NAME=$(printf '%s' "$FILE_PATH" | sed -nE 's|.*/projects/([^/]+)/.*|\1|p')
[[ -z "$PROJECT_NAME" ]] && exit 0

# Detectar si el path es un indice T1
IS_T1=0
case "$FILE_PATH" in
  */members/*.md|*/GLOSSARY.md|*/STAKEHOLDERS.md|*/INDEX.md|*/_HUB.md|*/MEMORY.md) IS_T1=1 ;;
  *.acm|*.hcm|*.afm) IS_T1=1 ;;
esac

[[ "$IS_T1" -eq 0 ]] && exit 0

TURN_ID="${CLAUDE_TURN_ID:-${CLAUDE_SESSION_ID:-default}}"
MARKER_DIR="${TMPDIR:-/tmp}/savia-turn-${TURN_ID}"
mkdir -p "$MARKER_DIR" 2>/dev/null || exit 0
: > "$MARKER_DIR/heuristic-t1-${PROJECT_NAME}" 2>/dev/null || exit 0
exit 0
