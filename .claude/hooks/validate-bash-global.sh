#!/bin/bash
# validate-bash-global.sh — Validación global de comandos Bash peligrosos
# Usado por: settings.json (PreToolUse hook para toda la sesión)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Bloquear git commit/add en rama main/master (evita commits accidentales)
if echo "$COMMAND" | grep -iE 'git\s+(commit|add)' > /dev/null; then
  CURRENT_BRANCH=$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    echo "BLOQUEADO: git commit/add en rama '$CURRENT_BRANCH'. Cambia a feature branch primero." >&2
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
