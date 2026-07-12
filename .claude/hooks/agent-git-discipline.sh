#!/usr/bin/env bash
# agent-git-discipline.sh — SE-266: Block destructive git ops for concurrent agent safety
# Inspired by Pi (earendil-works/pi AGENTS.md)
set -uo pipefail

INPUT=""
if INPUT=$(timeout 3 cat 2>/dev/null); then
  :
fi

COMMAND=""
if [[ -n "$INPUT" ]]; then
  COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""
fi

[[ -z "$COMMAND" ]] && exit 0

if ! echo "$COMMAND" | grep -qE '^[[:space:]]*git[[:space:]]+'; then
  exit 0
fi

# Block destructive worktree operations (exit 2 = BLOCK, matching convention)
if echo "$COMMAND" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
  echo "BLOCKED [agent-git-discipline]: destructive operation — destroys all agents uncommitted work." >&2
  exit 2
fi

if echo "$COMMAND" | grep -qE 'git[[:space:]]+clean'; then
  if echo "$COMMAND" | grep -qE 'clean[[:space:]].*(-[a-z]*n[a-z]*\b|-[a-z]*n\b|--dry-run)'; then
    :
  else
    echo "BLOCKED [agent-git-discipline]: destructive operation — deletes untracked files from all agents." >&2
    echo "  Use -n or --dry-run to preview first." >&2
    exit 2
  fi
fi

if echo "$COMMAND" | grep -qE 'git[[:space:]]+stash'; then
  echo "BLOCKED [agent-git-discipline]: git stash hides other agents staged changes." >&2
  echo "  Alternative: commit to agent branch." >&2
  exit 2
fi

if echo "$COMMAND" | grep -qE 'git[[:space:]]+checkout[[:space:]]+\.'; then
  echo "BLOCKED [agent-git-discipline]: git checkout . destroys working tree of all agents." >&2
  exit 2
fi

# Warn on global stage operations
if echo "$COMMAND" | grep -qE 'git[[:space:]]+add[[:space:]]+(-A|\.)[[:space:]]*$'; then
  echo "WARN [agent-git-discipline]: git add -A/. stages files from other agents." >&2
  echo "  Use: git add <path1> <path2>" >&2
fi

exit 0
