#!/bin/bash
# block-force-push.sh — Bloquea git push --force y commits directos a main
# Usado por: commit-guardian (PreToolUse hook)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Bloquear force push
if echo "$COMMAND" | grep -iE 'git\s+push\s+.*--force|git\s+push\s+-f\b' > /dev/null; then
  echo "BLOQUEADO: git push --force no está permitido. Usa git push sin --force." >&2
  exit 2
fi

# Bloquear push directo a main/master
if echo "$COMMAND" | grep -iE 'git\s+push\s+(origin\s+)?(main|master)\b' > /dev/null; then
  echo "BLOQUEADO: Push directo a main/master no permitido. Usa rama + PR." >&2
  exit 2
fi

# Bloquear commit --amend sin confirmación explícita
if echo "$COMMAND" | grep -iE 'git\s+commit\s+.*--amend' > /dev/null; then
  echo "BLOQUEADO: git commit --amend puede destruir commits anteriores. Crea un commit nuevo." >&2
  exit 2
fi

# Bloquear reset --hard
if echo "$COMMAND" | grep -iE 'git\s+reset\s+--hard' > /dev/null; then
  echo "BLOQUEADO: git reset --hard puede perder trabajo. Usa git stash o git revert." >&2
  exit 2
fi

exit 0
