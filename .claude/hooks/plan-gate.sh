#!/bin/bash
# plan-gate.sh — Warning si implementación sin spec aprobada
# ─────────────────────────────────────────────────────────────
# PreToolUse hook (Edit|Write) que advierte si se edita código sin spec
# Profile tier: standard
set -uo pipefail

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"
fi

# Timeout: 30 seconds max for entire spec search operation
TIMEOUT=30

# Solo verificar en ficheros de código fuente
FILE="${CLAUDE_TOOL_INPUT_FILE:-}"
[[ -z "$FILE" ]] && exit 0

case "$FILE" in
    *.cs|*.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.php|*.rb|*.java|*.kt|*.swift|*.dart|*.vb|*.cbl) ;;
    *) exit 0 ;;
esac

# Buscar spec activa en el proyecto
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SPECS_DIR="$PROJECT_DIR/projects"

# Si no hay directorio de proyectos, skip
[[ ! -d "$SPECS_DIR" ]] && exit 0

# Buscar specs recientes (último sprint = últimos 14 días) with timeout
RECENT_SPECS=$(timeout $TIMEOUT find "$SPECS_DIR" -name "*.spec.md" -mtime -14 2>/dev/null | head -5)

if [[ -z "$RECENT_SPECS" ]]; then
    echo ""
    echo "⚠️  Plan Gate: No se encontró spec aprobada reciente."
    echo "   Considera ejecutar /spec-generate antes de implementar."
    echo "   (Warning — no bloquea la edición)"
    echo ""
fi

exit 0
