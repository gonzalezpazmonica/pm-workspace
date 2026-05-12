#!/usr/bin/env bash
set -uo pipefail
# artifacts-confidentiality-gate.sh — PreToolUse hook
# Bloquea escrituras de artifacts que crucen niveles de confidencialidad.
# SPEC-AGENT-ARTIFACTS par.2.6 / SPEC-127. Rule #26.
# Protocol: stdin=JSON, exit 0=allow, exit 2=block.

TOOL="${TOOL_NAME:-}"
if [[ "$TOOL" != "Write" && "$TOOL" != "Edit" ]]; then
  exit 0
fi

INPUT="$(cat)"
TOOL_FILE_PATH="$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('path','') or d.get('file_path',''))
" 2>/dev/null || echo "")"

[[ -z "$TOOL_FILE_PATH" ]] && exit 0

DEST_LEVEL="N1"
if echo "$TOOL_FILE_PATH" | grep -qP '/N(3|4|4b)/'; then
  DEST_LEVEL="$(echo "$TOOL_FILE_PATH" | grep -oP 'N(4b|4|3|2)' | head -1)"
fi

AGENT_LEVEL="${SAVIA_AGENT_CONFIDENTIALITY:-N1}"

# Bloquear si agente con nivel elevado intenta escribir en nivel inferior
if [[ ( "$AGENT_LEVEL" == "N3" || "$AGENT_LEVEL" == "N4" || "$AGENT_LEVEL" == "N4b" ) \
   && ( "$DEST_LEVEL" == "N1" || "$DEST_LEVEL" == "N2" ) ]]; then
  echo "[artifacts-confidentiality-gate] BLOCKED: agente $AGENT_LEVEL -> dest $DEST_LEVEL" >&2
  exit 2
fi

exit 0
