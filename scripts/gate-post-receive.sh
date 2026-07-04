#!/usr/bin/env bash
# scripts/gate-post-receive.sh — SE-255
# Installed as post-receive hook in the bare gate repo.
# Clones the pushed branch into a temp worktree, runs pr-plan,
# signs confidentiality, and forwards to upstream if green.
set -euo pipefail

WORKTREE=""
cleanup() {
  if [[ -n "$WORKTREE" && -d "$WORKTREE" ]]; then
    rm -rf "$WORKTREE"
  fi
}
trap cleanup EXIT

GATE_REMOTE="upstream"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# Cache upstream URL from bare repo
UPSTREAM_URL=$(git remote get-url upstream 2>/dev/null || echo "")

while read -r old_sha new_sha ref; do
  [[ "$ref" =~ ^refs/heads/ ]] || continue
  branch="${ref#refs/heads/}"
  echo ""
  echo "=== Gate: $branch ==="

  # Detect bare repo path. $GIT_DIR may be '.' (relative) in hook context.
  WORKTREE=$(mktemp -d)
  GATE_REPO="$(cd "${GIT_DIR:-.}" && pwd)"
  unset GIT_DIR
  unset GIT_WORK_TREE
  git init --quiet "$WORKTREE"
  cd "$WORKTREE"

  if ! git fetch --quiet "$GATE_REPO" "$branch" 2>/dev/null; then
    echo -e "  ${RED}GATE ERROR${NC}: fetch failed (repo=$GATE_REPO branch=$branch)"
    continue
  fi
  git checkout -b "$branch" FETCH_HEAD --quiet 2>/dev/null || true

  [[ -n "$UPSTREAM_URL" ]] && git remote add upstream "$UPSTREAM_URL" 2>/dev/null || true

  echo "  Running pr-plan --gate-mode ..."
  echo ""

  if bash scripts/pr-plan.sh --gate-mode 2>&1; then
    echo ""
    echo -e "  pr-plan: ${GREEN}PASS${NC}"

    if [[ -f scripts/confidentiality-sign.sh ]]; then
      echo "  Signing ..."
      SAVIA_CONFIDENTIALITY_AUDITED=1 bash scripts/confidentiality-sign.sh sign 2>&1 | tail -1
      git add .confidentiality-signature 2>/dev/null || true
      git diff --cached --quiet 2>/dev/null || git commit -m "chore: gate-signed" 2>/dev/null || true
    fi

    echo "  Forwarding to $GATE_REMOTE/$branch ..."
    if git push "$GATE_REMOTE" "$branch" 2>&1; then
      echo -e "${GREEN}=== GATE PASSED -> $GATE_REMOTE/$branch ===${NC}"
    else
      echo -e "${RED}=== GATE ERROR${NC}: push failed ==="
    fi
  else
    echo ""
    echo -e "${RED}=== GATE BLOCKED${NC}: pr-plan failed for $branch ==="
  fi
done

exit 0
