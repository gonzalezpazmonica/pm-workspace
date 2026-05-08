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

# Bloquear force push (permite --force-with-lease en ramas no-main)
# --force-with-lease es más seguro: falla si el remoto avanzó sin nuestro conocimiento.
# Requerido en flujo de rebase de PRs en cola (SPEC-105).
IS_FORCE_WITH_LEASE=no
IS_BARE_FORCE=no
IS_PUSH_TO_MAIN=no

if echo "$COMMAND" | grep -iE '(^|[;&|])[[:space:]]*git[[:space:]]+push[[:space:]]+.*--force-with-lease' > /dev/null; then
  IS_FORCE_WITH_LEASE=yes
fi
if echo "$COMMAND" | grep -iE '(^|[;&|])[[:space:]]*git[[:space:]]+push[[:space:]]+(.*[[:space:]])?--force([[:space:]]|$)|(^|[;&|])[[:space:]]*git[[:space:]]+push[[:space:]]+-f[[:space:]]' > /dev/null; then
  IS_BARE_FORCE=yes
fi
if echo "$COMMAND" | grep -iE 'git[[:space:]]+push[[:space:]]+.*\b(main|master)\b' > /dev/null; then
  IS_PUSH_TO_MAIN=yes
fi

# Bare --force (sin --force-with-lease) siempre bloqueado
if [[ "$IS_BARE_FORCE" == "yes" && "$IS_FORCE_WITH_LEASE" == "no" ]]; then
  echo "BLOQUEADO: git push --force no está permitido. Usa --force-with-lease." >&2
  exit 2
fi

# --force-with-lease a main/master bloqueado (solo permitido en ramas feature)
if [[ "$IS_FORCE_WITH_LEASE" == "yes" && "$IS_PUSH_TO_MAIN" == "yes" ]]; then
  echo "BLOQUEADO: --force-with-lease a main/master no permitido." >&2
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
