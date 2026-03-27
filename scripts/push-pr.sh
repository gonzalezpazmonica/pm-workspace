#!/usr/bin/env bash
# push-pr.sh — CI + sign + push + create PR (zero re-sign commits)
# Usage: push-pr.sh [--title "title"] [--body "body"] [--draft] [--merge]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

TITLE="" BODY="" DRAFT=false MERGE=false SKIP_CL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --draft) DRAFT=true; shift ;;
    --merge) MERGE=true; shift ;;
    --skip-changelog) SKIP_CL=true; shift ;;
    --help|-h) echo "Usage: $0 [--title T] [--body B] [--draft] [--merge] [--skip-changelog]"; exit 0 ;;
    *) shift ;;
  esac
done

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$BRANCH" == "main" || "$BRANCH" == "master" ]] && { echo "ERROR: On $BRANCH." >&2; exit 1; }

# Detect repo from remote URL
REPO=$(git remote get-url origin | sed -E 's|.*github\.com[:/]||;s|\.git$||')
TOKEN=$(git remote get-url origin | grep -oP 'ghp_[A-Za-z0-9]+' 2>/dev/null || true)

# ── Steps 1-5: Validate → CI → CHANGELOG → Sign → Push ──────────────────
echo "=== Step 1: Working tree ==="
[[ -n "$(git diff --name-only 2>/dev/null)" ]] && { echo "ERROR: Uncommitted changes." >&2; exit 1; }
echo "  Clean."

echo -e "\n=== Step 2: CI local ==="
bash scripts/validate-ci-local.sh 2>&1 | tail -5 | grep -q "safe to push" || { echo "ERROR: CI failed." >&2; exit 1; }
echo "  Passed."

echo -e "\n=== Step 3: CHANGELOG ==="
if ! $SKIP_CL; then
  CL_V=$(grep -oP '## \[\K[0-9.]+' CHANGELOG.md | head -1)
  PREV_V=$(git show origin/main:CHANGELOG.md 2>/dev/null | grep -oP '## \[\K[0-9.]+' | head -1)
  [[ "$CL_V" == "$PREV_V" ]] && { echo "ERROR: CHANGELOG not updated. Use --skip-changelog if not needed." >&2; exit 1; }
  echo "  $CL_V."
else echo "  Skipped (--skip-changelog)."; fi

echo -e "\n=== Step 4: Sign ==="
bash scripts/confidentiality-sign.sh sign 2>&1 | tail -1
git add .confidentiality-signature
if ! git diff --cached --quiet; then
  git commit -m "chore: sign confidentiality audit
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
else echo "  Unchanged."; fi

echo -e "\n=== Step 5: Push ==="
export SAVIA_PUSH_PR=1
git push origin "$BRANCH" 2>&1 | tail -3

# ── Step 6: PR ───────────────────────────────────────────────────────────
echo -e "\n=== Step 6/6: PR ==="
[[ -z "$TOKEN" ]] && { echo "  No token. Create PR manually."; exit 0; }

# Auto-generate title from first commit if not provided
[[ -z "$TITLE" ]] && TITLE=$(git log origin/main..HEAD --oneline | tail -1 | cut -d' ' -f2-)

# Auto-generate body with ## Summary (PR Guardian Gate 1 requires >200 chars)
if [[ -z "$BODY" ]]; then
  COMMIT_LIST=$(git log --oneline origin/main..HEAD | sed 's/^/- /')
  FILE_COUNT=$(git diff origin/main..HEAD --stat | tail -1 | grep -oP '[0-9]+' | head -1)
  BODY="## Summary

${TITLE}

### Changes

${COMMIT_LIST}

### Stats

${FILE_COUNT} files changed across $(echo "$COMMIT_LIST" | wc -l) commits.

## Test plan

- [x] validate-ci-local.sh passed
- [x] Confidentiality signed

Generated with [Claude Code](https://claude.com/claude-code)"
fi

# Write body to temp file to avoid shell quoting issues
BODY_FILE=$(mktemp)
echo "$BODY" > "$BODY_FILE"
$DRAFT && DRAFT_PY="True" || DRAFT_PY="False"

PR_URL=$(python3 - "$TOKEN" "$REPO" "$BRANCH" "$TITLE" "$BODY_FILE" "$DRAFT_PY" << 'PYEOF'
import json,urllib.request,sys
token,repo,branch,title = sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
body = open(sys.argv[5]).read()
draft = sys.argv[6] == "True"
data = json.dumps({"title":title,"body":body,"head":branch,"base":"main","draft":draft}).encode()
req = urllib.request.Request(
    f"https://api.github.com/repos/{repo}/pulls",
    data=data,
    headers={"Authorization":f"token {token}","Accept":"application/vnd.github+json","Content-Type":"application/json"})
try:
    r = json.loads(urllib.request.urlopen(req).read())
    print(r.get("html_url","PR creation failed"))
except urllib.error.HTTPError as e:
    err = json.loads(e.read())
    if "already exists" in str(err):
        print(f"PR already exists for {branch}")
    else:
        print(f"Failed: {err.get('message',err)}", file=sys.stderr)
        print("PR creation failed")
PYEOF
)
rm -f "$BODY_FILE"
echo "  $PR_URL"

# ── Auto-merge (poll CI instead of fixed sleep) ─────────────────────────
if $MERGE && [[ "$PR_URL" == http* ]]; then
  PR_NUM=$(echo "$PR_URL" | grep -oP '[0-9]+$')
  echo "  Waiting for CI..."
  SHA=$(git rev-parse HEAD)
  for i in $(seq 1 12); do
    sleep 10
    RESULT=$(curl -s "https://api.github.com/repos/$REPO/commits/$SHA/check-runs" \
      -H "Authorization: token $TOKEN" | python3 -c "
import sys,json; d=json.load(sys.stdin)
pend=[r for r in d.get('check_runs',[]) if r['status']!='completed']
fail=[r for r in d.get('check_runs',[]) if r.get('conclusion') not in ('success','skipped',None) and r['status']=='completed']
if not pend and not fail and d.get('total_count',0)>0: print('GREEN')
elif fail: print('FAIL')
else: print('WAIT')
")
    [[ "$RESULT" == "GREEN" ]] && break
    [[ "$RESULT" == "FAIL" ]] && { echo "  CI failed. Merge aborted."; exit 1; }
    echo "  ... ($((i*10))s)"
  done
  if [[ "$RESULT" == "GREEN" ]]; then
    curl -s -X PUT "https://api.github.com/repos/$REPO/pulls/$PR_NUM/merge" \
      -H "Authorization: token $TOKEN" \
      -d "{\"merge_method\":\"squash\",\"commit_title\":\"$TITLE\"}" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('  Merged.' if 'sha' in d else f'  Merge: {d.get(\"message\",d)}')"
  else
    echo "  CI timeout after 120s. Merge manually."
  fi
fi

echo -e "\nDone."
