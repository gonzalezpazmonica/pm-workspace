#!/usr/bin/env bash
# block-branch-switch-dirty.sh — Prevent branch switch with uncommitted changes
# Tier: security (always active — protects against data loss)
# PreToolUse on Bash — intercepts git checkout/switch commands
set -uo pipefail

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  source "$LIB_DIR/profile-gate.sh" && profile_gate "security"
fi

# Read hook input
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(timeout 3 cat 2>/dev/null) || true
fi
[[ -z "$INPUT" ]] && exit 0

# Extract command from hook JSON
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Only check git checkout/switch commands that change branch
if ! echo "$COMMAND" | grep -qE 'git (checkout|switch)\s'; then
  exit 0
fi

# Skip file restores (git checkout -- file)
if echo "$COMMAND" | grep -qE 'git checkout\s+--\s'; then
  exit 0
fi

# Check for uncommitted changes (tracked + untracked)
DIRTY=$(git status --porcelain 2>/dev/null | head -20)
if [[ -n "$DIRTY" ]]; then
  TRACKED=$(echo "$DIRTY" | grep -cE '^ M| ^M|^MM|^A |^D ' || echo "0")
  UNTRACKED=$(echo "$DIRTY" | grep -c '^??' || echo "0")

  echo "BLOQUEADO: Cambio de rama con cambios sin commitear." >&2
  echo "" >&2
  echo "  Ficheros modificados: $TRACKED" >&2
  echo "  Ficheros sin rastrear: $UNTRACKED" >&2
  echo "" >&2
  echo "  Opciones:" >&2
  echo "    1. git add + git commit (recomendado)" >&2
  echo "    2. git stash -u (temporal)" >&2
  echo "" >&2
  echo "  NUNCA cambiar de rama sin guardar los cambios." >&2
  exit 2
fi

exit 0
