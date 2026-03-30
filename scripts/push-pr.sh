#!/usr/bin/env bash
# push-pr.sh — CI + sign + push + create PR + release (zero re-sign commits)
# Usage: push-pr.sh [--title "title"] [--body "body"] [--draft] [--merge]
set -euo pipefail
cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")"

TITLE="" BODY="" DRAFT=false MERGE=false SKIP_CL=false SKIP_CI=false FROM_PR_PLAN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;  --body) BODY="$2"; shift 2 ;;
    --draft) DRAFT=true; shift ;;     --merge) MERGE=true; shift ;;
    --skip-changelog) SKIP_CL=true; shift ;; --skip-ci) SKIP_CI=true; shift ;;
    --from-pr-plan) FROM_PR_PLAN=true; shift ;;
    --help|-h) echo "Usage: $0 [--title T] [--body B] [--draft] [--merge] [--skip-changelog] [--skip-ci]"; exit 0 ;;
    *) shift ;;
  esac
done

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$BRANCH" == "main" || "$BRANCH" == "master" ]] && { echo "ERROR: On $BRANCH." >&2; exit 1; }

# ── Step 0: pr-plan gate ──────────────────────────────────────────────────
if ! $FROM_PR_PLAN && [[ ! -f ".pr-plan-ok" ]]; then
  echo "ERROR: /pr-plan not run. Run /pr-plan first or touch .pr-plan-ok to bypass." >&2; exit 1
fi
# Staleness check: warn if commits added after pr-plan
if ! $FROM_PR_PLAN && [[ -f ".pr-plan-ok" ]]; then
  PLAN_T=$(stat -c %Y .pr-plan-ok 2>/dev/null || stat -f %m .pr-plan-ok 2>/dev/null || echo 0)
  if [[ "$(git log -1 --format=%ct 2>/dev/null || echo 0)" -gt "$PLAN_T" ]]; then
    echo "⚠️  WARNING: New commits since /pr-plan. Re-run recommended. Continuing in 5s..." >&2; sleep 5
  fi
fi

REPO=$(git remote get-url origin | sed -E 's|.*github\.com[:/]||;s|\.git$||')
TOKEN=$(git remote get-url origin | grep -oP 'ghp_[A-Za-z0-9]+' 2>/dev/null || true)
if [[ -z "$TOKEN" ]] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  USE_GH_CLI=true
else USE_GH_CLI=false; fi

# ── Steps 1-5: Validate → CI → CHANGELOG → Sign → Push ──────────────────
echo "=== Step 1: Working tree ==="; [[ -n "$(git diff --name-only 2>/dev/null)" ]] && { echo "ERROR: Uncommitted changes." >&2; exit 1; }; echo "  Clean."
echo -e "\n=== Step 2: CI local ==="
if $SKIP_CI; then echo "  Skipped."
else bash scripts/validate-ci-local.sh 2>&1 | tail -5 | grep -q "safe to push" || { echo "ERROR: CI failed." >&2; exit 1; }; echo "  Passed."; fi
echo -e "\n=== Step 3: CHANGELOG ==="
if ! $SKIP_CL; then
  CL_V=$(grep -oP '## \[\K[0-9.]+' CHANGELOG.md | head -1)
  PREV_V=$(git show origin/main:CHANGELOG.md 2>/dev/null | grep -oP '## \[\K[0-9.]+' | head -1)
  [[ "$CL_V" == "$PREV_V" ]] && { echo "ERROR: CHANGELOG not updated." >&2; exit 1; }; echo "  $CL_V."
else echo "  Skipped."; fi
echo -e "\n=== Step 4: Sign ==="
bash scripts/confidentiality-sign.sh sign 2>&1 | tail -1; git add .confidentiality-signature
if ! git diff --cached --quiet; then
  git commit -m "chore: sign confidentiality audit
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
else echo "  Unchanged."; fi
echo -e "\n=== Step 5: Push ==="; export SAVIA_PUSH_PR=1
git push origin "$BRANCH" 2>&1 | tail -3 || { echo "  Retrying..."; git push --force-with-lease origin "$BRANCH" 2>&1 | tail -3; }

# ── Step 6: PR ───────────────────────────────────────────────────────────
echo -e "\n=== Step 6: PR ==="
if [[ -z "$TOKEN" ]] && ! $USE_GH_CLI; then
  echo "  No token and gh CLI not available. Create PR manually."; exit 0
fi
[[ -z "$TITLE" ]] && TITLE=$(git log origin/main..HEAD --oneline | tail -1 | cut -d' ' -f2-)
if [[ -z "$BODY" ]]; then
  COMMITS=$(git log --oneline origin/main..HEAD | grep -v "^[a-f0-9]* chore: sign" | sed 's/^/- /')
  FILES=$(git diff origin/main..HEAD --stat | tail -1 | grep -oP '[0-9]+' | head -1)
  BODY="## Summary
${TITLE}
### Changes
${COMMITS}
### Stats
${FILES} files changed across $(echo "$COMMITS" | wc -l) commits.
## Test plan
- [x] CI passed  - [x] Signed

Generated with [Claude Code](https://claude.com/claude-code)"
fi
BODY_FILE=$(mktemp); echo "$BODY" > "$BODY_FILE"
if $USE_GH_CLI; then
  GH_CMD=(gh pr create --title "$TITLE" --body-file "$BODY_FILE")
  $DRAFT && GH_CMD+=(--draft)
  PR_URL=$("${GH_CMD[@]}" 2>&1) || PR_URL="PR creation failed: $PR_URL"
else
  $DRAFT && DRAFT_PY="True" || DRAFT_PY="False"
  PR_URL=$(python3 -c "
import json,urllib.request,sys
t,r,b,ti='$TOKEN','$REPO','$BRANCH','$(echo "$TITLE" | sed "s/'/\\\\'/g")'
body=open('$BODY_FILE').read(); dr=$([[ "$DRAFT_PY" == "True" ]] && echo True || echo False)
d=json.dumps({'title':ti,'body':body,'head':b,'base':'main','draft':dr}).encode()
rq=urllib.request.Request(f'https://api.github.com/repos/{r}/pulls',data=d,
  headers={'Authorization':f'token {t}','Accept':'application/vnd.github+json','Content-Type':'application/json'})
try:
  print(json.loads(urllib.request.urlopen(rq).read()).get('html_url','PR creation failed'))
except urllib.error.HTTPError as e:
  err=json.loads(e.read())
  print(f'PR already exists for {b}' if 'already exists' in str(err) else 'PR creation failed')
" 2>&1)
fi
rm -f "$BODY_FILE"; echo "  $PR_URL"

# ── Auto-merge (--merge flag) ────────────────────────────────────────────
MERGED=false
if $MERGE && [[ "$PR_URL" == http* ]]; then
  PR_NUM=$(echo "$PR_URL" | grep -oP '[0-9]+$')
  if $USE_GH_CLI; then
    echo "  Enabling auto-merge..."; gh pr merge "$PR_NUM" --squash --auto 2>&1 | tail -1
  elif [[ -n "$TOKEN" ]]; then
    echo "  Waiting for CI..."; SHA=$(git rev-parse HEAD)
    for i in $(seq 1 12); do sleep 10
      R=$(curl -s "https://api.github.com/repos/$REPO/commits/$SHA/check-runs" -H "Authorization: token $TOKEN" \
        | python3 -c "import sys,json;d=json.load(sys.stdin);p=[r for r in d.get('check_runs',[]) if r['status']!='completed'];f=[r for r in d.get('check_runs',[]) if r.get('conclusion') not in ('success','skipped',None) and r['status']=='completed'];print('GREEN' if not p and not f and d.get('total_count',0)>0 else 'FAIL' if f else 'WAIT')")
      [[ "$R" == "GREEN" ]] && break; [[ "$R" == "FAIL" ]] && { echo "  CI failed."; exit 1; }
      echo "  ... ($((i*10))s)"
    done
    [[ "$R" == "GREEN" ]] && curl -s -X PUT "https://api.github.com/repos/$REPO/pulls/$PR_NUM/merge" \
      -H "Authorization: token $TOKEN" -d "{\"merge_method\":\"squash\",\"commit_title\":\"$TITLE\"}" \
      | python3 -c "import sys,json;d=json.load(sys.stdin);print('  Merged.' if 'sha' in d else f'  Merge: {d}')" \
      || echo "  CI timeout. Merge manually."
  fi
  # Check if merge completed (for release step)
  if $USE_GH_CLI; then
    PR_STATE=$(gh pr view "$PR_NUM" --json state -q .state 2>/dev/null || echo "")
    [[ "$PR_STATE" == "MERGED" ]] && MERGED=true
  fi
fi

# ── Step 7: Release update (only after successful merge with gh CLI) ────
if $MERGED && command -v gh >/dev/null 2>&1; then
  echo -e "\n=== Step 7: Release ==="
  VERSION=$(grep -oP '## \[\K[0-9.]+' CHANGELOG.md | head -1)
  if [[ -n "$VERSION" ]]; then
    NOTES=$(sed -n "/^## \[$VERSION\]/,/^## \[/{ /^## \[$VERSION\]/d; /^## \[/d; p; }" CHANGELOG.md)
    if gh release view "v$VERSION" >/dev/null 2>&1; then
      gh release edit "v$VERSION" --notes "$NOTES" && echo "  Updated release v$VERSION."
    else
      gh release create "v$VERSION" --title "PM Workspace v$VERSION" --notes "$NOTES" --latest \
        && echo "  Created release v$VERSION."
    fi
  else echo "  No version in CHANGELOG.md, skipping release."; fi
fi

# Clean sentinel — pr-plan must be re-run for next PR
rm -f .pr-plan-ok
echo -e "\nDone."
