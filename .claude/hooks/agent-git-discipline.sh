#!/usr/bin/env bash
# agent-git-discipline.sh — SE-266: Block destructive git ops for concurrent agent safety
# Inspired by Pi (earendil-works/pi AGENTS.md)
set -uo pipefail

INPUT=$(cat) || true

if ! echo "$INPUT" | grep -qE '^[[:space:]]*git[[:space:]]+'; then
  echo "$INPUT"
  exit 0
fi

# Block destructive worktree operations
R="reset --hard"
C="clean -fd"
S="stash"
O="checkout ."

if echo "$INPUT" | grep -qE "git[[:space:]]+${R// /[[:space:]]+}"; then
  echo "BLOCKED [agent-git-discipline]: destructive operation — destroys all agents uncommitted work." >&2
  exit 1
fi

if echo "$INPUT" | grep -qE "git[[:space:]]+${C// /[[:space:]]+}"; then
  echo "BLOCKED [agent-git-discipline]: destructive operation — deletes untracked files from all agents." >&2
  exit 1
fi

if echo "$INPUT" | grep -qE "git[[:space:]]+stash"; then
  echo "BLOCKED [agent-git-discipline]: git stash hides other agents staged changes." >&2
  echo "  Alternative: commit to agent branch." >&2
  exit 1
fi

if echo "$INPUT" | grep -qE "git[[:space:]]+checkout[[:space:]]+\."; then
  echo "BLOCKED [agent-git-discipline]: git checkout . destroys working tree of all agents." >&2
  exit 1
fi

# Warn on global stage operations
if echo "$INPUT" | grep -qE 'git[[:space:]]+add[[:space:]]+(-A|\.)[[:space:]]*$'; then
  echo "WARN [agent-git-discipline]: git add -A/. stages files from other agents." >&2
  echo "  Use: git add <path1> <path2>" >&2
fi

echo "$INPUT"
exit 0
