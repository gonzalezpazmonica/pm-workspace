#!/usr/bin/env bash
# pr-plan.sh — 10-gate pre-flight + sign + push + PR
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"; cd "$ROOT"

DRY=false; SKIP_PUSH=false; TITLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=true; shift ;; --skip-push) SKIP_PUSH=true; shift ;;
    --title) TITLE="$2"; shift 2 ;; *) shift ;;
  esac
done

BRANCH=$(git rev-parse --abbrev-ref HEAD)
PASS=0; FAIL=0; WARN=0; STOPPED=""
sep() { printf '  %-4s %-28s %s\n' "$1" "$2" "$3"; }

gate() {
  local id="$1" name="$2"; shift 2
  [[ -n "$STOPPED" ]] && return
  local result; result=$("$@" 2>&1) || true
  if echo "$result" | grep -q "^FAIL:"; then
    sep "$id" "$name" "FAIL"; FAIL=$((FAIL+1))
    STOPPED="$id: $(echo "$result" | sed 's/^FAIL://')"
  elif echo "$result" | grep -q "^WARN:"; then
    sep "$id" "$name" "WARN ($(echo "$result" | sed 's/^WARN://'))"
    WARN=$((WARN+1))
  else
    sep "$id" "$name" "PASS${result:+ ($result)}"; PASS=$((PASS+1))
  fi
}

g1() {
  [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]] && echo "FAIL: Switch to feature branch" && return
  echo "$BRANCH"
}
g2() {
  [[ -n "$(git diff --name-only 2>/dev/null)" ]] && echo "FAIL: Commit or stash changes first" && return
}
g3() {
  local marker; marker="<""<""<""<""<""<""<"
  local c; c=$(grep -rln "^${marker}" --include='*.md' --include='*.sh' --include='*.py' --include='*.json' . 2>/dev/null | grep -v '.git/' | grep -v 'worktrees/' | head -5) || true
  [[ -n "$c" ]] && echo "FAIL: Merge conflicts in: $c" && return
}
g4() {
  git fetch origin main --quiet 2>/dev/null || true
  git merge-base --is-ancestor origin/main HEAD 2>/dev/null || { echo "FAIL: Rebase onto main first"; return; }
  echo "0 behind"
}
g5() {
  local hi; hi=$(git diff origin/main..HEAD --name-only 2>/dev/null | grep -E '^(\.claude/(rules|hooks|agents|skills|settings)|scripts/|docs/|CLAUDE\.md)' || true)
  [[ -z "$hi" ]] && echo "skipped" && return
  local lv; lv=$(grep -oP '## \[\K[0-9.]+' CHANGELOG.md 2>/dev/null | head -1)
  local mv; mv=$(git show origin/main:CHANGELOG.md 2>/dev/null | grep -oP '## \[\K[0-9.]+' | head -1) || true
  [[ "$lv" == "$mv" ]] && echo "FAIL: CHANGELOG not updated (both $lv)" && return
  echo "v$lv"
}
g6() {
  command -v bats >/dev/null 2>&1 || { echo "WARN: bats not installed"; return; }
  # Windows Git Bash: BATS has path issues, degrade to WARN
  [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]] && { echo "WARN: Windows — BATS deferred to CI"; return; }
  local out; out=$(bash tests/run-all.sh 2>&1) || true
  local fails; fails=$(echo "$out" | grep '❌' | sed 's/.*❌ //' | tr '\n' ', ' | sed 's/, $//') || true
  [[ -n "$fails" ]] && echo "FAIL: $fails" && return
  local p; p=$(echo "$out" | grep -oP '[0-9]+/[0-9]+ suites' | tail -1)
  echo "${p:-ok}"
}
g7() {
  local out; out=$(bash scripts/confidentiality-scan.sh --pr 2>&1) || true
  echo "$out" | grep -q "BLOCKED" && { echo "FAIL: $(echo "$out" | grep 'FAIL ' | head -3 | tr '\n' '; ')"; return; }
  echo "0 violations"
}
g8() {
  local nf; nf=$(git diff origin/main..HEAD --diff-filter=A --name-only 2>/dev/null) || true
  local need=false
  echo "$nf" | grep -qE '^\.claude/(commands|skills|agents)/' && need=true
  $need && ! echo "$nf" | grep -q 'README.md' && { echo "WARN: new components, README not updated"; return; }
}
g9() {
  local names; names=$(ls -d projects/*/ 2>/dev/null | xargs -I{} basename {} | grep -vE '^(_|team-|savia-web$)') || true
  [[ -z "$names" ]] && return
  # Only scan ADDED lines in the diff, not full file content
  local added; added=$(git diff origin/main..HEAD | grep '^+' | grep -v '^+++' || true)
  [[ -z "$added" ]] && return
  local leaks=""
  for n in $names; do
    echo "$added" | grep -q "$n" && leaks="$leaks $n in diff;"
  done
  [[ -n "$leaks" ]] && echo "FAIL: Private data:$leaks"
}
g10() {
  local out; out=$(bash scripts/validate-ci-local.sh 2>&1) || true
  echo "$out" | grep -q "safe to push" || { echo "FAIL: CI issues (run validate-ci-local.sh)"; return; }
}

# ── Run gates ────────────────────────────────────────────────────
echo "------------------------------------------------------------"
echo "  PR Pre-Flight — $BRANCH"
echo "------------------------------------------------------------"
echo ""
gate "G1"  "Branch safety"         g1
gate "G2"  "Clean working tree"    g2
gate "G3"  "No merge conflicts"    g3
gate "G4"  "Divergence from main"  g4
gate "G5"  "CHANGELOG audit"       g5
gate "G6"  "BATS tests"            g6
gate "G7"  "Confidentiality scan"  g7
gate "G8"  "Documentation check"   g8
gate "G9"  "Zero project leakage"  g9
gate "G10" "CI validation"         g10
echo ""
echo "------------------------------------------------------------"
if [[ -n "$STOPPED" ]]; then
  echo "  STOPPED at $STOPPED"
  echo "------------------------------------------------------------"
  exit 1
fi
echo "  Result: $PASS PASS | $FAIL FAIL | $WARN WARN"
echo "------------------------------------------------------------"
$DRY && { echo -e "\n  --dry-run: no push."; exit 0; }

echo -e "\n  Signing..."
bash scripts/confidentiality-sign.sh sign 2>&1 | tail -1
git add .confidentiality-signature 2>/dev/null
git diff --cached --quiet 2>/dev/null || git commit -m "chore: sign confidentiality audit
Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>" --quiet
$SKIP_PUSH && { echo "  --skip-push: signed only."; exit 0; }

echo "  Pushing + PR..."
export SAVIA_PUSH_PR=1
PUSH_ARGS="--skip-changelog"
[[ -n "$TITLE" ]] && PUSH_ARGS="$PUSH_ARGS --title \"$TITLE\""
bash scripts/push-pr.sh $PUSH_ARGS 2>&1 | grep -E "(http|PR |Done)" | tail -3
echo "------------------------------------------------------------"
