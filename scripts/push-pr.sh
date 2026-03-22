#!/usr/bin/env bash
# push-pr.sh — CI + sign + push + create PR (zero re-sign commits)
# Usage: push-pr.sh [--title "title"] [--body "body"] [--draft] [--merge]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

TITLE="" BODY="" DRAFT=false MERGE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --draft) DRAFT=true; shift ;;
    --merge) MERGE=true; shift ;;
    --help|-h) echo "Usage: $0 [--title T] [--body B] [--draft] [--merge]"; exit 0 ;;
    *) shift ;;
  esac
done

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "ERROR: On $BRANCH. Create a feature branch first." >&2; exit 1
fi

# ── Step 1: Verify nothing pending ──────────────────────────────────────
echo "=== Step 1/6: Check working tree ==="
if [[ -n "$(git diff --name-only)" ]]; then
  echo "ERROR: Uncommitted changes. Commit everything first." >&2
  git diff --name-only >&2; exit 1
fi
echo "  Clean."

# ── Step 2: Run CI local ────────────────────────────────────────────────
echo ""
echo "=== Step 2/6: CI local ==="
if ! bash scripts/validate-ci-local.sh 2>&1 | tail -5 | grep -q "safe to push"; then
  echo "ERROR: CI local failed. Fix issues first." >&2; exit 1
fi
echo "  CI passed."

# ── Step 3: Check CHANGELOG if rules/hooks changed ──────────────────────
echo ""
echo "=== Step 3/6: CHANGELOG gate ==="
DIFF_FILES=$(git diff origin/main..HEAD --name-only 2>/dev/null || true)
NEEDS_CL=false
echo "$DIFF_FILES" | grep -qE '\.claude/(rules|hooks|agents|skills)/' && NEEDS_CL=true
if $NEEDS_CL; then
  CL_VERSION=$(grep -oP '## \[\K[0-9.]+' CHANGELOG.md | head -1)
  PREV_CL=$(git show origin/main:CHANGELOG.md 2>/dev/null | grep -oP '## \[\K[0-9.]+' | head -1)
  if [[ "$CL_VERSION" == "$PREV_CL" ]]; then
    echo "ERROR: Rules/hooks changed but CHANGELOG not updated." >&2
    echo "  Add entry for new version in CHANGELOG.md, then re-run." >&2
    exit 1
  fi
  echo "  CHANGELOG updated ($CL_VERSION)."
else
  echo "  No high-impact files — CHANGELOG not required."
fi

# ── Step 4: Sign confidentiality ─────────────────────────────────────────
echo ""
echo "=== Step 4/6: Confidentiality sign ==="
bash scripts/confidentiality-sign.sh sign
git add .confidentiality-signature
if git diff --cached --quiet; then
  echo "  Signature unchanged."
else
  git commit -m "chore: sign confidentiality audit

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
  echo "  Signed and committed."
fi

# ── Step 5: Push ─────────────────────────────────────────────────────────
echo ""
echo "=== Step 5/6: Push ==="
git push origin "$BRANCH"
echo "  Pushed."

# ── Step 6: Create PR (if title provided) ────────────────────────────────
echo ""
echo "=== Step 6/6: PR ==="
if [[ -z "$TITLE" ]]; then
  TITLE=$(git log --oneline -1 | cut -d' ' -f2-)
fi
if [[ -z "$BODY" ]]; then
  BODY=$(git log --oneline origin/main..HEAD | sed 's/^/- /')
fi

TOKEN=$(git remote get-url origin | grep -oP 'ghp_[A-Za-z0-9]+' || true)
if [[ -z "$TOKEN" ]]; then
  echo "  No GitHub token in remote URL. Create PR manually:"
  echo "  https://github.com/.../pull/new/$BRANCH"
  exit 0
fi

DRAFT_JSON="false"; $DRAFT && DRAFT_JSON="true"
PR_URL=$(curl -s -X POST "https://api.github.com/repos/gonzalezpazmonica/pm-workspace/pulls" \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d "$(python3 -c "
import json,sys
print(json.dumps({
  'title': '''$TITLE''',
  'body': '''$BODY''',
  'head': '$BRANCH',
  'base': 'main',
  'draft': $DRAFT_JSON == 'true'
}))
")" | python3 -c "import sys,json; print(json.load(sys.stdin).get('html_url','PR creation failed'))")

echo "  PR: $PR_URL"

if $MERGE; then
  echo "  Waiting 60s for CI..."
  sleep 60
  PR_NUM=$(echo "$PR_URL" | grep -oP '[0-9]+$')
  curl -s -X PUT "https://api.github.com/repos/gonzalezpazmonica/pm-workspace/pulls/$PR_NUM/merge" \
    -H "Authorization: token $TOKEN" \
    -d '{"merge_method":"squash"}' | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('  Merged.' if 'sha' in d else f'  Merge failed: {d.get(\"message\",d)}')
"
fi

echo ""
echo "Done."
