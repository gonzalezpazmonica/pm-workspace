#!/bin/bash
set -uo pipefail
# safe-edit.sh — Wrapper para ediciones que ejecuta hooks de calidad
# DEPRECATED — SE-077 Slice 1+2 (2026-04-26): replaced by
#   ~/.savia/opencode/plugins/savia-gates/ which delegates to .claude/hooks/*.sh
#   directly. Conservar 1 sprint, eliminar tras Slice 2 completion (AC-11).
# Uso: safe-edit.sh <file-path>
# Nota: Este script solo valida; la edición real debe hacerse con la herramienta Edit de OpenCode.

FILE_PATH="$1"
CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
HOOKS_DIR="$CLAUDE_PROJECT_DIR/.claude/hooks"
RUN_HOOK="$CLAUDE_PROJECT_DIR/.opencode/scripts/opencode-hooks/run-hook.sh"

if [ -z "$FILE_PATH" ]; then
    echo "Error: Proporciona una ruta de archivo." >&2
    exit 1
fi

# 1. Plan gate (warning si no hay spec)
echo "📋 Verificando spec aprobada..." >&2
"$RUN_HOOK" plan-gate Edit "$FILE_PATH" || true  # Solo warning, no bloquea

# 2. TDD gate (bloquea si no hay tests para código de producción)
echo "🧪 Verificando tests..." >&2
if ! "$RUN_HOOK" tdd-gate Edit "$FILE_PATH"; then
    echo "❌ Edición bloqueada por TDD gate." >&2
    exit 1
fi

echo "✅ Validación superada. Puedes editar $FILE_PATH con OpenCode." >&2
echo "   Usa la herramienta Edit de OpenCode para modificar el archivo."
