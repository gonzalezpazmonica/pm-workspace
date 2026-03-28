#!/bin/bash
set -uo pipefail
# block-force-push.sh — Bloquea git push --force y commits directos a main
# Usado por: commit-guardian (PreToolUse hook)
# Profile tier: security

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "security"
fi

# Read stdin with timeout to avoid hanging if no input arrives
# Uses timeout+cat to handle input that may lack trailing newline
INPUT=""
if INPUT=$(timeout 3 cat 2>/dev/null); then
  :
fi

# Require jq for safe JSON parsing
if ! command -v jq &>/dev/null; then
  echo "ADVERTENCIA: jq no está instalado. Instala jq para activar protección de force-push." >&2
  exit 0
fi
COMMAND=""
if [[ -n "$INPUT" ]]; then
  COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""
fi

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
