#!/bin/bash
set -uo pipefail
# safe-bash.sh — Wrapper para comandos Bash que ejecuta hooks de seguridad
# DEPRECATED — SE-077 Slice 1+2 (2026-04-26): replaced by
#   ~/.savia/opencode/plugins/savia-gates/ which delegates to .claude/hooks/*.sh
#   directly. Conservar 1 sprint, eliminar tras Slice 2 completion (AC-11).
# Uso: safe-bash.sh "comando"

COMMAND="$*"
CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
HOOKS_DIR="$CLAUDE_PROJECT_DIR/.claude/hooks"
RUN_HOOK="$CLAUDE_PROJECT_DIR/.opencode/scripts/opencode-hooks/run-hook.sh"

if [ -z "$COMMAND" ]; then
    echo "Error: Proporciona un comando." >&2
    exit 1
fi

# 1. Validación de comandos peligrosos
echo "🔒 Validando seguridad del comando..." >&2
if ! "$RUN_HOOK" validate-bash-global Bash "$COMMAND"; then
    echo "❌ Comando bloqueado por validate-bash-global." >&2
    exit 1
fi

# 2. Detección de secrets en el comando
if ! "$RUN_HOOK" block-credential-leak Bash "$COMMAND"; then
    echo "❌ Comando bloqueado por block-credential-leak." >&2
    exit 1
fi

# 3. Detección de infraestructura destructiva
if ! "$RUN_HOOK" block-infra-destructive Bash "$COMMAND"; then
    echo "❌ Comando bloqueado por block-infra-destructive." >&2
    exit 1
fi

echo "✅ Validación superada. Ejecutando comando..." >&2
eval "$COMMAND"
