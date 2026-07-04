#!/usr/bin/env bash
# scripts/gate-post-receive.sh — SE-255
# Installed as post-receive hook in the bare gate repo.
# Receives pushed refs, checks out in temp worktree, runs pr-plan,
# signs confidentiality, and forwards to origin-upstream if green.
#
# This hook NEVER blocks at git level (always exits 0).
# Forward/no-forward is determined by pr-plan result.
set -euo pipefail

WORKTREE=""
cleanup() {
  if [[ -n "$WORKTREE" && -d "$WORKTREE" ]]; then
    rm -rf "$WORKTREE"
  fi
}
trap cleanup EXIT

UPSTREAM_REMOTE="origin-upstream"
GREEN='\033[0;32m'; RED='\033[0;31m'; YEL='\033[0;33m'; NC='\033[0m'

while read -r old_sha new_sha ref; do
  # Only process branches, skip tags
  [[ "$ref" =~ ^refs/heads/ ]] || continue

  branch="${ref#refs/heads/}"
  echo ""
  echo "=== Gate received: $branch ($old_sha -> $new_sha) ==="
  echo ""

  # Create temp worktree
  WORKTREE=$(mktemp -d)
  echo "  Worktree: $WORKTREE"

  # Checkout the pushed branch into worktree
  if ! git --git-dir="$GIT_DIR" --work-tree="$WORKTREE" checkout -f "$new_sha" 2>/dev/null; then
    echo -e "  ${RED}GATE ERROR${NC}: failed to checkout $new_sha"
    continue
  fi

  # Run pr-plan in gate mode (non-interactive, exit 1 on failure)
  cd "$WORKTREE"
  echo "  Running pr-plan --gate-mode ..."
  echo ""

  if bash scripts/pr-plan.sh --gate-mode 2>&1; then
    echo ""
    echo "  pr-plan: ${GREEN}PASS${NC}"

    # Sign confidentiality
    if [[ -f scripts/confidentiality-sign.sh ]]; then
      echo "  Signing confidentiality ..."
      SAVIA_CONFIDENTIALITY_AUDITED=1 bash scripts/confidentiality-sign.sh sign 2>&1 | tail -1
      git add .confidentiality-signature 2>/dev/null || true
      if ! git diff --cached --quiet 2>/dev/null; then
        git commit -m "chore: gate-signed" 2>/dev/null || true
      fi
    fi

    # Forward to upstream
    echo "  Forwarding to $UPSTREAM_REMOTE/$branch ..."
    if git push "$UPSTREAM_REMOTE" "$branch" 2>&1; then
      echo ""
      echo -e "${GREEN}=== GATE PASSED → pushed to $UPSTREAM_REMOTE/$branch ===${NC}"
    else
      echo ""
      echo -e "${RED}=== GATE ERROR${NC}: push to $UPSTREAM_REMOTE failed ==="
    fi
  else
    echo ""
    echo -e "${RED}=== GATE BLOCKED${NC}: pr-plan failed for $branch ==="
    echo "  Fix the issues above and push again."
  fi
done

exit 0
