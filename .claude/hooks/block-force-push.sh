#!/bin/bash
# block-force-push.sh — Bloquea git push --force y commits directos a main
# Usado por: commit-guardian (PreToolUse hook)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Bloquear force push
# FIX: Add anchoring for compound command separators (semicolon, &&, ||, pipe)
if echo "$COMMAND" | grep -iE '(^|[;&|])[[:space:]]*git[[:space:]]+push[[:space:]]+.*--force|(^|[;&|])[[:space:]]*git[[:space:]]+push[[:space:]]+-f[[:space:]]' > /dev/null; then
  echo "BLOQUEADO: git push --force no está permitido. Usa git push sin --force." >&2
  exit 2
fi

# Bloquear push directo a main/master
# FIX: Add anchoring for compound command separators
if echo "$COMMAND" | grep -iE '(^|[;&|])[[:space:]]*git[[:space:]]+push[[:space:]]+(origin[[:space:]]+)?(main|master)([[:space:]]|$|[;&|])' > /dev/null; then
  echo "BLOQUEADO: Push directo a main/master no permitido. Usa rama + PR." >&2
  exit 2
fi

# Bloquear commit --amend sin confirmación explícita
# FIX: Add anchoring for compound command separators
if echo "$COMMAND" | grep -iE '(^|[;&|])[[:space:]]*git[[:space:]]+commit[[:space:]]+.*--amend' > /dev/null; then
  echo "BLOQUEADO: git commit --amend puede destruir commits anteriores. Crea un commit nuevo." >&2
  exit 2
fi

# Bloquear reset --hard
# FIX: Add anchoring for compound command separators
if echo "$COMMAND" | grep -iE '(^|[;&|])[[:space:]]*git[[:space:]]+reset[[:space:]]+--hard' > /dev/null; then
  echo "BLOQUEADO: git reset --hard puede perder trabajo. Usa git stash o git revert." >&2
  exit 2
fi

exit 0
