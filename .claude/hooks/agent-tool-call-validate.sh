#!/bin/bash
# agent-tool-call-validate.sh — Validacion de parametros antes de ejecutar tools
# Tier: standard | Async: false | Event: PreToolUse
set -euo pipefail

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
[[ -f "$LIB_DIR/profile-gate.sh" ]] && source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"

INPUT="$(cat)"
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"

# Si no hay nombre de herramienta en env, extraer del input
if [[ -z "$TOOL_NAME" ]]; then
  TOOL_NAME=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', d.get('name', '')))
except:
    print('')
" 2>/dev/null || true)
fi

[[ -z "$TOOL_NAME" ]] && exit 0  # Sin herramienta identificada → pass-through

# Extraer tool_input
TOOL_INPUT=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(json.dumps(d.get('tool_input', d.get('input', {}))))
except:
    print('{}')
" 2>/dev/null || echo '{}')

validate_file_path() {
  local fp
  fp=$(echo "$TOOL_INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('file_path', ''))
except:
    print('')
" 2>/dev/null || true)
  if [[ -z "$fp" ]]; then
    echo "BLOQUEADO [$TOOL_NAME]: file_path es obligatorio y no puede estar vacío." >&2
    exit 2
  fi
}

validate_bash_command() {
  local cmd
  cmd=$(echo "$TOOL_INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('command', ''))
except:
    print('')
" 2>/dev/null || true)
  if [[ -z "$cmd" ]]; then
    echo "BLOQUEADO [Bash]: command es obligatorio y no puede estar vacío." >&2
    exit 2
  fi
}

case "$TOOL_NAME" in
  Edit|Write|Read)
    validate_file_path
    ;;
  Bash)
    validate_bash_command
    ;;
  *)
    # Herramienta no validada → pass-through
    exit 0
    ;;
esac

exit 0
