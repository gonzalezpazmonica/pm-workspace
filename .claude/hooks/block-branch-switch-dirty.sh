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

# Extract command + session cwd from hook JSON (two lines: command, cwd)
PARSED=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
cmd = d.get('tool_input', {}).get('command', '') or ''
print(cmd.replace(chr(10), ' '))
print(d.get('cwd', '') or '')
" 2>/dev/null)
COMMAND=$(echo "$PARSED" | sed -n '1p')
SESSION_CWD=$(echo "$PARSED" | sed -n '2p')
[[ -z "$COMMAND" ]] && exit 0

# Only check git checkout/switch commands that change branch (also `git -C <dir> switch`)
if ! echo "$COMMAND" | grep -qE 'git (-C\s+\S+\s+)?(checkout|switch)\s'; then
  exit 0
fi

# Skip file restores (git checkout -- file)
if echo "$COMMAND" | grep -qE 'git checkout\s+--\s'; then
  exit 0
fi

# Resolve the repo the command actually targets. The hook's own cwd is the
# workspace, NOT necessarily the repo the command runs in (cd X && git switch).
# Priority: `git -C <dir>` > leading `cd <dir> &&|;` > session cwd (hook JSON) > hook cwd.
TARGET_DIR=""
if [[ "$COMMAND" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]\;\&\|]+) ]]; then
  TARGET_DIR="${BASH_REMATCH[1]}"
elif [[ "$COMMAND" =~ (^|[[:space:]]|\&\&|\;)cd[[:space:]]+([^[:space:]\;\&\|]+)[[:space:]]*(\&\&|\;) ]]; then
  TARGET_DIR="${BASH_REMATCH[2]}"
elif [[ -n "$SESSION_CWD" ]]; then
  TARGET_DIR="$SESSION_CWD"
fi
# Strip surrounding quotes, expand ~ / $HOME, resolve relative to session cwd
TARGET_DIR="${TARGET_DIR%\"}"; TARGET_DIR="${TARGET_DIR#\"}"
TARGET_DIR="${TARGET_DIR%\'}"; TARGET_DIR="${TARGET_DIR#\'}"
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
TARGET_DIR="${TARGET_DIR/#\$HOME/$HOME}"
if [[ -n "$TARGET_DIR" && "$TARGET_DIR" != /* && -n "$SESSION_CWD" ]]; then
  TARGET_DIR="$SESSION_CWD/$TARGET_DIR"
fi
[[ -z "$TARGET_DIR" ]] && TARGET_DIR="$PWD"
[[ -d "$TARGET_DIR" ]] || exit 0

# Not a git repo → nothing to protect
TARGET_ROOT=$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Check for uncommitted changes (tracked + untracked) IN THE TARGET REPO
DIRTY=$(git -C "$TARGET_DIR" status --porcelain 2>/dev/null | head -20)
if [[ -n "$DIRTY" ]]; then
  TRACKED=$(echo "$DIRTY" | grep -cE '^ M| ^M|^MM|^A |^D ' || echo "0")
  UNTRACKED=$(echo "$DIRTY" | grep -c '^??' || echo "0")

  echo "BLOQUEADO: Cambio de rama con cambios sin commitear." >&2
  echo "" >&2
  echo "  Repo: $TARGET_ROOT" >&2
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

# SE-300: clear stale per-branch PR summary on legitimate branch switch so a
# previous PR's natural-language paragraph does not leak into the next PR body.
# Only when the switch happens in THIS workspace — never touch another repo's state.
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
if [[ "$(cd "$TARGET_ROOT" && pwd -P)" == "$WORKSPACE_ROOT" && -f "$WORKSPACE_ROOT/.pr-summary.md" ]]; then
  rm -f "$WORKSPACE_ROOT/.pr-summary.md"
fi

exit 0
