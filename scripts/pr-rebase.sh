#!/usr/bin/env bash
# pr-rebase.sh — Rebase current PR branch onto origin/main and re-sign.
# Handles the common conflict on .confidentiality-signature automatically.
#
# Use case: PR B is queued behind PR A. When A merges, B needs to rebase onto
# new main. The only conflict is typically .confidentiality-signature (each
# branch has its own). This script resolves it by keeping ours, then re-signs
# with the new (stable) merge-base.
#
# Usage:
#   bash scripts/pr-rebase.sh              # rebase onto origin/main
#   bash scripts/pr-rebase.sh --no-push    # local only, don't push
#
# Exit codes:
#   0 — rebase + resign + push successful
#   1 — working tree dirty (commit or stash first)
#   2 — rebase had non-signature conflicts (manual intervention needed)
#   3 — signing or push failed
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SIG_FILE="$ROOT/.confidentiality-signature"
DO_PUSH=true

for arg in "$@"; do
  case "$arg" in
    --no-push) DO_PUSH=false ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0 ;;
  esac
done

cd "$ROOT" || exit 2

# ── Pre-flight checks ──────────────────────────────────────────────────────
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "ERROR: cannot rebase while on $BRANCH" >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree has uncommitted changes. Commit or stash first." >&2
  exit 1
fi

echo "─────────────────────────────────────────────────────────────"
echo "  pr-rebase — $BRANCH onto origin/main"
echo "─────────────────────────────────────────────────────────────"

# ── Fetch latest main ──────────────────────────────────────────────────────
echo "  Fetching origin/main..."
git fetch origin main --quiet || {
  echo "ERROR: fetch failed" >&2
  exit 3
}

# ── Rebase ──────────────────────────────────────────────────────────────────
BEHIND=$(git rev-list --count HEAD..origin/main)
if [[ "$BEHIND" -eq 0 ]]; then
  echo "  Already up to date with origin/main — nothing to rebase."
else
  echo "  Rebasing $BEHIND commits from origin/main..."
  # Start rebase; it may conflict multiple times (once per queued commit
  # that touched .confidentiality-signature). Loop auto-resolving until
  # rebase completes or hits a non-signature conflict.
  git rebase origin/main >/tmp/pr-rebase-output.log 2>&1 || true

  MAX_ITER=50
  ITER=0
  while [[ -d .git/rebase-merge || -d .git/rebase-apply ]]; do
    ITER=$((ITER + 1))
    if [[ $ITER -gt $MAX_ITER ]]; then
      echo "ERROR: rebase exceeded $MAX_ITER iterations, aborting." >&2
      git rebase --abort 2>/dev/null || true
      exit 2
    fi

    CONFLICTS=$(git diff --name-only --diff-filter=U)
    if [[ "$CONFLICTS" == ".confidentiality-signature" ]]; then
      git checkout --ours .confidentiality-signature 2>/dev/null
      git add .confidentiality-signature
      git -c core.editor=true rebase --continue >>/tmp/pr-rebase-output.log 2>&1 || true
    elif [[ -z "$CONFLICTS" ]]; then
      # Empty commit case (changes became no-op after rebase)
      git -c core.editor=true rebase --skip >>/tmp/pr-rebase-output.log 2>&1 || true
    else
      echo "ERROR: rebase conflicts not limited to signature file:" >&2
      echo "$CONFLICTS" | sed 's/^/  /' >&2
      echo "Run 'git rebase --abort' and resolve manually." >&2
      exit 2
    fi
  done
  echo "  Rebase complete after $ITER auto-resolution(s)."
fi

# ── Re-sign with the new merge-base ────────────────────────────────────────
echo "  Re-signing with updated merge-base..."
bash "$SCRIPT_DIR/confidentiality-sign.sh" sign | tail -1

if ! git diff --quiet "$SIG_FILE" 2>/dev/null; then
  git add "$SIG_FILE"
  git commit --no-verify -m "chore: sign confidentiality audit after rebase

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>" \
    2>&1 | tail -2
fi

# ── Push (with lease) ──────────────────────────────────────────────────────
if $DO_PUSH; then
  echo "  Pushing with --force-with-lease..."
  if git push --force-with-lease origin "$BRANCH" 2>&1 | tail -2; then
    echo "  Done."
  else
    echo "ERROR: push failed (remote may have diverged further)." >&2
    exit 3
  fi
else
  echo "  Skipped push (--no-push)."
fi

echo "─────────────────────────────────────────────────────────────"
