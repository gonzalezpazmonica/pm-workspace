#!/bin/bash
set -uo pipefail
# safe-task.sh — Wrapper para tareas (Task) que valida el prompt antes de enviar a un agente
# DEPRECATED — SE-077 Slice 1+2 (2026-04-26): replaced by
#   ~/.savia/opencode/plugins/savia-gates/ which delegates to .claude/hooks/*.sh
#   directly. Conservar 1 sprint, eliminar tras Slice 2 completion (AC-11).
# Uso: safe-task.sh "<prompt>"
# Nota: Este script solo valida; la tarea real debe lanzarse con la herramienta Task de OpenCode.

PROMPT="$*"
CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
RUN_HOOK="$CLAUDE_PROJECT_DIR/.opencode/scripts/opencode-hooks/run-hook.sh"

if [ -z "$PROMPT" ]; then
    echo "Error: Proporciona un prompt." >&2
    exit 1
fi

echo "🤖 Validando prompt para agente..." >&2
if ! "$RUN_HOOK" agent-dispatch-validate Task "$PROMPT"; then
    echo "❌ Prompt bloqueado por validación de agente." >&2
    exit 1
fi

echo "✅ Validación superada. Puedes lanzar el agente con OpenCode." >&2
echo "   Usa la herramienta Task de OpenCode con el prompt proporcionado."
