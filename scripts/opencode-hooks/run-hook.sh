#!/bin/bash
set -uo pipefail
# run-hook.sh — Ejecuta un hook de PM‑Workspace con el input JSON adecuado
# Uso: run-hook.sh <hook-name> [tool-name] [command-or-file]
# Ejemplos:
#   run-hook.sh validate-bash-global Bash "rm -rf /"
#   run-hook.sh block-force-push Bash "git push origin main"
#   run-hook.sh pre-commit-review

HOOK_NAME="$1"
HOOK_SCRIPT="$CLAUDE_PROJECT_DIR/.opencode/hooks/$HOOK_NAME.sh"

if [ ! -f "$HOOK_SCRIPT" ]; then
    echo "Error: hook script $HOOK_SCRIPT no encontrado." >&2
    exit 1
fi

TOOL_NAME="${2:-}"
INPUT="${3:-}"

# Construir JSON simulado con jq (escapado seguro)
if [ -n "$TOOL_NAME" ]; then
    case "$TOOL_NAME" in
        Bash)
            JSON=$(jq -n --arg cmd "$INPUT" '{"tool_name":"Bash","tool_input":{"command":$cmd}}')
            ;;
        Edit|Write)
            JSON=$(jq -n --arg path "$INPUT" '{"tool_name":$tool,"tool_input":{"file_path":$path}}' --arg tool "$TOOL_NAME")
            ;;
        Task)
            JSON=$(jq -n --arg prompt "$INPUT" '{"tool_name":"Task","tool_input":{"prompt":$prompt}}')
            ;;
        *)
            JSON=$(jq -n --arg tool "$TOOL_NAME" '{"tool_name":$tool,"tool_input":{}}')
            ;;
    esac
else
    # Sin tool (ej. hooks de Stop/SessionStart)
    JSON="{}"
fi

# Ejecutar hook con el JSON por stdin
echo "$JSON" | "$HOOK_SCRIPT"