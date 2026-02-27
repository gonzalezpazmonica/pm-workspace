#!/bin/bash
# block-infra-destructive.sh — Bloquea operaciones destructivas de infraestructura
# Usado por: infrastructure-agent (PreToolUse hook)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Bloquear terraform destroy sin excepción
if echo "$COMMAND" | grep -iE 'terraform\s+destroy' > /dev/null; then
  echo "BLOQUEADO: terraform destroy requiere aprobación humana directa. No ejecutar desde agente." >&2
  exit 2
fi

# Bloquear terraform apply en PRE/PRO (detectar por variable o directorio)
if echo "$COMMAND" | grep -iE 'terraform\s+apply' > /dev/null; then
  if echo "$COMMAND" | grep -iE '(pre|pro|prod|staging|production)' > /dev/null; then
    echo "BLOQUEADO: terraform apply en PRE/PRO requiere aprobación humana. Solo permitido en DEV." >&2
    exit 2
  fi
fi

# Bloquear eliminación de resource groups completos
if echo "$COMMAND" | grep -iE 'az\s+group\s+delete' > /dev/null; then
  echo "BLOQUEADO: Eliminación de Resource Group requiere aprobación humana." >&2
  exit 2
fi

# Bloquear aws cloudformation delete-stack
if echo "$COMMAND" | grep -iE 'aws\s+cloudformation\s+delete-stack' > /dev/null; then
  echo "BLOQUEADO: delete-stack requiere aprobación humana." >&2
  exit 2
fi

# Bloquear kubectl delete namespace
if echo "$COMMAND" | grep -iE 'kubectl\s+delete\s+namespace' > /dev/null; then
  echo "BLOQUEADO: Eliminación de namespace Kubernetes requiere aprobación humana." >&2
  exit 2
fi

exit 0
