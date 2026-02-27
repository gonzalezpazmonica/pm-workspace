#!/bin/bash
# stop-quality-gate.sh — Verifica quality gates antes de que Claude termine
# Usado por: settings.json (Stop hook)
# Solo actúa si hay cambios pendientes en el directorio de trabajo

INPUT=$(cat)
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# Evitar loop infinito: si ya estamos en un Stop hook, no volver a verificar
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

# Verificar si hay cambios en el working tree
CHANGES=$(git diff --name-only 2>/dev/null | wc -l)
STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l)

if [ "$CHANGES" -eq 0 ] && [ "$STAGED" -eq 0 ]; then
  # No hay cambios, no necesitamos verificar
  exit 0
fi

# Verificar si hay ficheros con secrets potenciales en los cambios
SECRETS_FOUND=$(git diff --cached --diff-filter=ACM 2>/dev/null | grep -icE '(password|secret|api[_-]?key|token|private[_-]?key)=["\x27][A-Za-z0-9]' || true)

if [ "$SECRETS_FOUND" -gt 0 ]; then
  jq -n '{
    decision: "block",
    reason: "Se detectaron posibles secrets en los cambios staged. Revisa antes de continuar."
  }'
  exit 0
fi

exit 0
