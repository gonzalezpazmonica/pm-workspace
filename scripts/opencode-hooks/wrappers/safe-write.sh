#!/bin/bash
set -uo pipefail
# safe-write.sh — Wrapper para escritura de archivos que ejecuta hooks de calidad
# DEPRECATED — SE-077 Slice 1+2 (2026-04-26): replaced by
#   ~/.savia/opencode/plugins/savia-gates/ which delegates to .opencode/hooks/*.sh
#   directly. Conservar 1 sprint, eliminar tras Slice 2 completion (AC-11).
# Uso: safe-write.sh <file-path>
# Nota: Este script solo valida; la escritura real debe hacerse con la herramienta Write de OpenCode.

FILE_PATH="$1"
CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
RUN_HOOK="$CLAUDE_PROJECT_DIR/.opencode/scripts/opencode-hooks/run-hook.sh"

if [ -z "$FILE_PATH" ]; then
    echo "Error: Proporciona una ruta de archivo." >&2
    exit 1
fi

# 1. Plan gate (warning si no hay spec)
echo "📋 Verificando spec aprobada..." >&2
"$RUN_HOOK" plan-gate Write "$FILE_PATH" || true  # Solo warning, no bloquea

# 2. TDD gate (bloquea si no hay tests para código de producción)
echo "🧪 Verificando tests..." >&2
if ! "$RUN_HOOK" tdd-gate Write "$FILE_PATH"; then
    echo "❌ Escritura bloqueada por TDD gate." >&2
    exit 1
fi

echo "✅ Validación superada. Puedes escribir $FILE_PATH con OpenCode." >&2
echo "   Usa la herramienta Write de OpenCode para crear el archivo."
