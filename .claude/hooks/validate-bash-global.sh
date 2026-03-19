#!/bin/bash
set -uo pipefail
# validate-bash-global.sh — Validación global de comandos Bash peligrosos
# Usado por: settings.json (PreToolUse hook para toda la sesión)

# Read stdin JSON robustly — consume all available data with timeout
# Claude Code sends tool input as JSON on stdin to PreToolUse hooks.
# Uses timeout+cat instead of read -t (which requires trailing newline).
INPUT=""
if INPUT=$(timeout 3 cat 2>/dev/null); then
  :
fi

# Parse command from JSON — exit cleanly on any parse failure
COMMAND=""
if [[ -n "$INPUT" ]]; then
  COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""
fi

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Bloquear git commit/add en rama main/master (evita commits accidentales)
if echo "$COMMAND" | grep -iE 'git\s+(commit|add)' > /dev/null; then
  # Detect target directory: if command starts with "cd <path> &&", use that path
  # This handles multi-repo setups where the git repo differs from CLAUDE_PROJECT_DIR
  GIT_DIR_TARGET="$CLAUDE_PROJECT_DIR"
  CD_PATH=$(echo "$COMMAND" | grep -oP '^\s*cd\s+"([^"]+)"' | sed 's/^\s*cd\s*"//;s/"$//' 2>/dev/null)
  if [[ -n "$CD_PATH" ]] && [[ -d "$CD_PATH/.git" ]]; then
    GIT_DIR_TARGET="$CD_PATH"
  fi
  CURRENT_BRANCH=$(cd "$GIT_DIR_TARGET" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    echo "BLOQUEADO: git commit/add en rama '$CURRENT_BRANCH' ($GIT_DIR_TARGET). Cambia a feature branch primero." >&2
    exit 2
  fi
fi

# Bloquear rm -rf / (root)
if echo "$COMMAND" | grep -iE 'rm\s+-rf\s+/' > /dev/null; then
  echo "BLOQUEADO: rm -rf con ruta root. Operación potencialmente destructiva." >&2
  exit 2
fi

# Bloquear chmod 777
if echo "$COMMAND" | grep -iE 'chmod\s+777' > /dev/null; then
  echo "BLOQUEADO: chmod 777 es inseguro. Usa permisos más restrictivos." >&2
  exit 2
fi

# Bloquear curl | bash (ejecución remota ciega)
if echo "$COMMAND" | grep -iE 'curl\s+.*\|\s*(ba)?sh' > /dev/null; then
  echo "BLOQUEADO: curl | bash es inseguro. Descarga primero, revisa, luego ejecuta." >&2
  exit 2
fi

# Bloquear auto-aprobación de PRs (GitHub no lo permite y es mala práctica)
if echo "$COMMAND" | grep -iE 'gh\s+pr\s+review.*--approve' > /dev/null; then
  echo "BLOQUEADO: No puedes aprobar tu propio PR. Asigna un reviewer o usa branch protection." >&2
  exit 2
fi

# Bloquear merge directo sin revisión (bypass de branch protection)
if echo "$COMMAND" | grep -iE 'gh\s+pr\s+merge.*--admin' > /dev/null; then
  echo "BLOQUEADO: --admin bypass de protección de rama. Requiere revisión humana." >&2
  exit 2
fi

# Bloquear sudo sin excepción explícita
# FIX: \s not POSIX ERE. Use [[:space:]] instead.
if echo "$COMMAND" | grep -iE '^[[:space:]]*sudo[[:space:]]' > /dev/null; then
  echo "BLOQUEADO: sudo no permitido desde agentes. Solicita elevación al PM." >&2
  exit 2
fi

exit 0
