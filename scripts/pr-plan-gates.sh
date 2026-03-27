#!/usr/bin/env bash
# pr-plan-gates.sh — Gate functions for pr-plan.sh (sourced, not executed)

g0() {
  [[ ! -f "$FAILURE_FILE" ]] && return
  local info; info=$(python3 -c "import json;d=json.load(open('$FAILURE_FILE'));print(d['failed_file'],d['ts'],d['gate'])" 2>/dev/null) || { rm -f "$FAILURE_FILE"; return; }
  local ff ts gate; read -r ff ts gate <<< "$info"
  [[ -z "$ff" || "$ff" == "unknown" ]] && { rm -f "$FAILURE_FILE"; return; }
  local file_ts; file_ts=$(git log -1 --format=%cI -- "$ff" 2>/dev/null) || file_ts=""
  if [[ -n "$file_ts" && -n "$ts" ]] && [[ "$file_ts" < "$ts" ]]; then
    FAILED_FILE="$ff"
    echo "FAIL: Previous $gate failure — fix $ff before retrying"; return
  fi
  echo "resolved — $ff modified"; rm -f "$FAILURE_FILE"
}

gate() {
  local id="$1" name="$2"; shift 2
  [[ -n "$STOPPED" ]] && return
  printf '  %-4s %-28s ...\n' "$id" "$name"
  local t0=$SECONDS
  local result; result=$("$@" 2>&1) || true
  local dt=$(( SECONDS - t0 ))
  local timing=""; (( dt > 2 )) && timing=" ${dt}s"
  if echo "$result" | grep -q "^FAIL:"; then
    sep "$id" "$name" "FAIL${timing}"; FAIL=$((FAIL+1))
    STOPPED="$id: $(echo "$result" | sed 's/^FAIL://')"
    record_failure "$id" "$(echo "$result" | sed 's/^FAIL://')" "${FAILED_FILE:-unknown}"
    FAILED_FILE=""
  elif echo "$result" | grep -q "^WARN:"; then
    sep "$id" "$name" "WARN ($(echo "$result" | sed 's/^WARN://'))${timing}"
    WARN=$((WARN+1))
  else
    sep "$id" "$name" "PASS${result:+ ($result)}${timing}"; PASS=$((PASS+1))
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
  local all; all=$(git diff origin/main..HEAD --name-only 2>/dev/null) || true
  # Docs-only PRs (all .md files) are exempt, matching PR Guardian Gate 8
  local non_md; non_md=$(echo "$all" | grep -vE '\.md$' | grep -v '^$' || true)
  [[ -z "$non_md" ]] && echo "skipped (docs-only)" && return
  local hi; hi=$(echo "$all" | grep -E '^(\.claude/(rules|hooks|agents|skills|settings)|scripts/|CLAUDE\.md)' || true)
  [[ -z "$hi" ]] && echo "skipped" && return
  local lv; lv=$(grep -oP '## \[\K[0-9.]+' CHANGELOG.md 2>/dev/null | head -1)
  local mv; mv=$(git show origin/main:CHANGELOG.md 2>/dev/null | grep -oP '## \[\K[0-9.]+' | head -1) || true
  [[ "$lv" == "$mv" ]] && { FAILED_FILE="CHANGELOG.md"; echo "FAIL: CHANGELOG not updated (both $lv)"; return; }
  # Verify Era reference in latest entry (required by BATS test-changelog-integrity)
  local era; era=$(sed -n "/## \[$lv\]/,/## \[/p" CHANGELOG.md | grep -ci 'era ' || true)
  [[ "$era" -eq 0 ]] && { FAILED_FILE="CHANGELOG.md"; echo "FAIL: CHANGELOG v$lv missing Era reference (add 'Era NNN' to description)"; return; }
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
