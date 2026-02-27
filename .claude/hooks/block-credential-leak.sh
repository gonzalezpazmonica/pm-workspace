#!/bin/bash
# block-credential-leak.sh — Detecta credentials en comandos y ficheros
# Usado por: security-guardian (PreToolUse hook)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Patrones de secrets comunes
SECRETS_PATTERN='(password|passwd|secret|api[_-]?key|token|bearer|auth[_-]?token|private[_-]?key|connection[_-]?string|client[_-]?secret)=["\x27]?[A-Za-z0-9+/=_-]{8,}'

# Detectar secrets hardcodeados en comandos
if echo "$COMMAND" | grep -iEo "$SECRETS_PATTERN" > /dev/null 2>&1; then
  echo "BLOQUEADO: Posible secret detectado en el comando. Usa variables de entorno o vault." >&2
  exit 2
fi

# Detectar PAT hardcodeado (Azure DevOps / GitHub)
if echo "$COMMAND" | grep -iE '(pat|token)\s*[:=]\s*["\x27]?[a-z0-9]{40,}' > /dev/null 2>&1; then
  echo "BLOQUEADO: PAT/token hardcodeado detectado. Usa \$(cat \$PAT_FILE) o vault." >&2
  exit 2
fi

# Detectar echo de secrets a ficheros
if echo "$COMMAND" | grep -iE 'echo\s+.*secret.*>>' > /dev/null 2>&1; then
  echo "BLOQUEADO: No escribir secrets en ficheros. Usa config.local/ o vault." >&2
  exit 2
fi

exit 0
