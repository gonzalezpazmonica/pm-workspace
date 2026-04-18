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
_resolve_changelog_conflict() {
  local mv; mv=$(git show origin/main:CHANGELOG.md 2>/dev/null | grep -oP '## \[\K[0-9.]+' | head -1) || true
  [[ -z "$mv" ]] && { sed -i '/^<<<<<<< HEAD$/d; /^=======$/d; /^>>>>>>> origin\/main$/d' CHANGELOG.md; return; }
  git show origin/main:CHANGELOG.md > /tmp/_cl_base.md 2>/dev/null || true
  local my_entry=""
  my_entry=$(sed -n "1,/^## \[$mv\]/{ /^## \[$mv\]/d; p; }" CHANGELOG.md \
    | sed '/^<<<<<<</d; /^=======/d; /^>>>>>>>/d' \
    | sed '/^# Changelog/d; /^$/d; /^All notable/d; /^The format/d; /adheres to/d' || true)
  if [[ -z "$my_entry" ]]; then
    sed -i '/^<<<<<<< HEAD$/d; /^=======$/d; /^>>>>>>> origin\/main$/d' CHANGELOG.md; return
  fi
  local header_end
  header_end=$(grep -n '^## \[' /tmp/_cl_base.md | head -1 | cut -d: -f1) || header_end=8
  header_end=$((header_end - 1))
  head -"$header_end" /tmp/_cl_base.md > /tmp/_cl_new.md
  echo "" >> /tmp/_cl_new.md
  echo "$my_entry" >> /tmp/_cl_new.md
  tail -n +"$((header_end + 1))" /tmp/_cl_base.md >> /tmp/_cl_new.md
  local lv; lv=$(echo "$my_entry" | grep -oP '## \[\K[0-9.]+' | head -1) || true
  if [[ -n "$lv" ]]; then
    local prev
    prev=$(git tag --sort=-v:refname 2>/dev/null | grep -E '^v[0-9]' | head -2 | tail -1 | sed 's/^v//') || true
    [[ -z "$prev" ]] && prev=$(echo "$lv" | awk -F. '{ m=$2-1; if(m<0){m=0}; printf "%d.%d.0", $1, m }')
    local repo_url
    repo_url=$(git remote get-url origin 2>/dev/null \
      | sed 's/\.git$//; s|git@github.com:|https://github.com/|; s|https://[^@]*@|https://|') || repo_url=""
    if [[ -n "$repo_url" ]]; then
      local link="[$lv]: $repo_url/compare/v$prev...v$lv"
      local link_line; link_line=$(grep -n "^\[$mv\]:" /tmp/_cl_new.md | head -1 | cut -d: -f1) || true
      [[ -n "$link_line" ]] && sed -i "${link_line}i\\$link" /tmp/_cl_new.md
    fi
  fi
  cp /tmp/_cl_new.md CHANGELOG.md
  rm -f /tmp/_cl_base.md /tmp/_cl_new.md
}

_resolve_signature_conflict() {
  rm -f .confidentiality-signature
  git rm .confidentiality-signature 2>/dev/null || true
}

g4() {
  git fetch origin main --quiet 2>/dev/null || true
  if git merge-base --is-ancestor origin/main HEAD 2>/dev/null; then
    echo "0 behind"; return
  fi
  trap 'rm -f /tmp/_cl_base.md /tmp/_cl_new.md' RETURN
  git merge origin/main --no-ff --no-edit 2>&1 >/dev/null || true
  local hard_conflicts
  hard_conflicts=$(git diff --name-only --diff-filter=U 2>/dev/null \
    | grep -vE '^CHANGELOG\.md$|\.confidentiality-signature$' | head -5) || true
  if [[ -n "$hard_conflicts" ]]; then
    git merge --abort 2>/dev/null || true
    echo "FAIL: Merge conflicts in: $hard_conflicts"; return
  fi
  if grep -q '^<<<<<<<' CHANGELOG.md 2>/dev/null; then
    _resolve_changelog_conflict
    git add CHANGELOG.md
  fi
  if git diff --name-only --diff-filter=U 2>/dev/null | grep -q '\.confidentiality-signature'; then
    _resolve_signature_conflict
  fi
  local remaining; remaining=$(git diff --name-only --diff-filter=U 2>/dev/null) || true
  if [[ -n "$remaining" ]]; then
    git merge --abort 2>/dev/null || true
    echo "FAIL: Unresolved conflicts: $remaining"; return
  fi
  git commit --no-edit 2>/dev/null || true
  echo "auto-merged"
}
g5() {
  local all; all=$(git diff origin/main..HEAD --name-only 2>/dev/null) || true
  local non_md; non_md=$(echo "$all" | grep -vE '\.md$' | grep -v '^$' || true)
  [[ -z "$non_md" ]] && echo "skipped (docs-only)" && return
  local hi; hi=$(echo "$all" | grep -E '^(\.claude/(rules|hooks|agents|skills|settings)|scripts/|CLAUDE\.md)' || true)
  [[ -z "$hi" ]] && echo "skipped" && return

  # Accept CHANGELOG.d/*.md fragment as valid changelog entry (zero-conflict
  # pattern — see CHANGELOG.d/README.md). If the PR adds a fragment, skip
  # the top-version check; release consolidates fragments into CHANGELOG.md.
  local frag; frag=$(echo "$all" | grep -E '^CHANGELOG\.d/.+\.md$' | grep -v 'README\.md$' || true)
  if [[ -n "$frag" ]]; then
    local frag_count; frag_count=$(echo "$frag" | wc -l)
    echo "skipped (fragment pattern: $frag_count CHANGELOG.d/ file(s))"
    return
  fi

  local lv; lv=$(grep -oP '## \[\K[0-9.]+' CHANGELOG.md 2>/dev/null | head -1)
  local mv; mv=$(git show origin/main:CHANGELOG.md 2>/dev/null | grep -oP '## \[\K[0-9.]+' | head -1) || true
  [[ "$lv" == "$mv" ]] && { FAILED_FILE="CHANGELOG.md"; echo "FAIL: CHANGELOG not updated (both $lv) — use scripts/changelog-fragment.sh or bump top version"; return; }
  local era; era=$(sed -n "/## \[$lv\]/,/## \[/p" CHANGELOG.md | grep -ci 'era ' || true)
  [[ "$era" -eq 0 ]] && { FAILED_FILE="CHANGELOG.md"; echo "FAIL: CHANGELOG v$lv missing Era reference (add 'Era NNN' to description)"; return; }
  # G5.5 — PR queue: enforce lv > max_claimed (Era 210+219).
  if command -v gh >/dev/null 2>&1 && [[ "${PR_PLAN_SKIP_QUEUE_CHECK:-0}" != "1" ]]; then
    local repo; repo=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null) || repo=""
    if [[ -n "$repo" ]]; then
      local prs; prs=$(gh pr list --state open --json number,headRefName --jq '.[] | [.number, .headRefName] | @tsv' 2>/dev/null) || prs=""
      local claimed_list="" max_claimed="$mv"
      while IFS=$'\t' read -r pr_num pr_branch; do
        [[ -z "$pr_branch" || "$pr_branch" == "$BRANCH" ]] && continue
        local other_v
        other_v=$(gh api "repos/$repo/contents/CHANGELOG.md?ref=$pr_branch" --jq '.content' 2>/dev/null \
          | base64 -d 2>/dev/null | grep -oP '^## \[\K[0-9.]+' | head -1) || other_v=""
        [[ -z "$other_v" ]] && continue
        claimed_list="$claimed_list $other_v(#$pr_num)"
        if [[ -z "$max_claimed" ]] || \
           [[ "$(printf '%s\n%s\n' "$max_claimed" "$other_v" | sort -V | tail -1)" == "$other_v" ]]; then
          max_claimed="$other_v"
        fi
      done <<< "$prs"
      if [[ -n "$max_claimed" ]] && [[ "$lv" == "$max_claimed" || \
         "$(printf '%s\n%s\n' "$lv" "$max_claimed" | sort -V | tail -1)" != "$lv" ]]; then
        FAILED_FILE="CHANGELOG.md"
        local suggested; suggested=$(echo "$max_claimed" | awk -F. '{ printf "%d.%d.0\n", $1, $2+1 }')
        echo "FAIL: version $lv <= max in queue $max_claimed${claimed_list:+ (claimed:$claimed_list)} — bump to $suggested"
        return
      fi
    fi
  fi
  echo "v$lv"
}
# G5b — Extended CI checks (runs the same 6 checks CI runs: skills frontmatter,
# rule deps, hook safety flags, agent file size, doc link validation, CHANGELOG
# version reference links). Catches CI failures that would otherwise require a
# push + failed CI run + re-push cycle. ~2s. SPEC-031 slice 3 v2 lesson.
g5b() {
  [[ ! -x scripts/ci-extended-checks.sh ]] && { echo "WARN: ci-extended-checks.sh missing or not executable"; return; }
  local out; out=$(bash scripts/ci-extended-checks.sh 2>&1) || true
  local fail_count; fail_count=$(echo "$out" | grep -oP '[0-9]+(?= failed)' | head -1) || fail_count=""
  if [[ -n "$fail_count" ]] && [[ "$fail_count" =~ ^[0-9]+$ ]] && [[ "$fail_count" -gt 0 ]]; then
    local first_fail; first_fail=$(echo "$out" | grep '❌' | head -1 | sed 's/^[[:space:]]*❌[[:space:]]*//')
    FAILED_FILE="CHANGELOG.md"
    echo "FAIL: $fail_count extended-checks failed (first: $first_fail)"
    return
  fi
  echo "6 checks pass"
}

# G6b — Test Quality Gate for CHANGED test files only. Runs the SPEC-055
# auditor (80-point threshold) on every *.bats added/modified in the PR.
# Skipped if no test files changed. Keeps costs low (~2-5s per file) while
# preventing the classic "push + CI fails on low-score test" loop.
g6b() {
  [[ ! -x scripts/test-auditor.sh ]] && { echo "WARN: test-auditor.sh missing"; return; }
  local changed; changed=$(git diff origin/main..HEAD --name-only --diff-filter=AM 2>/dev/null | grep -E '^tests/.*\.bats$' || true)
  [[ -z "$changed" ]] && { echo "skipped (no *.bats changed)"; return; }
  local low=""
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    local score; score=$(bash scripts/test-auditor.sh "$f" 2>/dev/null \
      | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo 0)
    if [[ -n "$score" ]] && [[ "$score" -lt 80 ]]; then
      low="${low} ${f}=${score}"
    fi
  done <<< "$changed"
  if [[ -n "$low" ]]; then
    FAILED_FILE=$(echo "$low" | awk '{print $1}' | cut -d= -f1)
    echo "FAIL: test quality below 80:${low}"
    return
  fi
  local n; n=$(echo "$changed" | wc -l)
  echo "$n file(s) ≥80"
}

g6() {
  command -v bats >/dev/null 2>&1 || { echo "WARN: bats not installed"; return; }
  # Windows Git Bash: BATS has path issues, degrade to WARN
  [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]] && { echo "WARN: Windows — BATS deferred to CI"; return; }
  local out; out=$(timeout 300 bash tests/run-all.sh 2>&1) || true
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
  local safe='^(_|team-|savia-web$|savia-mobile-android$|savia-monitor$|pm-workspace$|proyecto-alpha$|proyecto-beta$|sala-reservas$|example$|test$|demo$|sample$|template$)'
  local names; names=$(ls -d projects/*/ 2>/dev/null | xargs -I{} basename {} | grep -vE "$safe") || true
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
g11() {
  local stat_line
  if ! git rev-parse origin/main >/dev/null 2>&1; then
    echo "WARN: Review level: unknown (origin/main unreachable)"; return
  fi
  stat_line=$(git diff origin/main..HEAD --stat 2>/dev/null | tail -1) || true
  if [[ -z "$stat_line" ]]; then
    echo "0 lines — nothing to review"; return
  fi
  local ins; ins=$(echo "$stat_line" | grep -oP '[0-9]+(?= insertion)' || echo 0)
  local dels; dels=$(echo "$stat_line" | grep -oP '[0-9]+(?= deletion)' || echo 0)
  local size=$(( ${ins:-0} + ${dels:-0} ))
  [[ $size -eq 0 ]] && { echo "0 lines — nothing to review"; return; }
  local size_tier=""
  if [[ $size -lt 50 ]]; then size_tier="XS"
  elif [[ $size -le 300 ]]; then size_tier="STANDARD"
  elif [[ $size -le 1000 ]]; then size_tier="ENHANCED"
  else size_tier="FULL"; fi
  local risk_tier="" risk_score="" escalated=""
  if [[ -f "output/risk-score.json" ]]; then
    risk_score=$(jq -r '.score // empty' output/risk-score.json 2>/dev/null) || true
    if [[ -n "$risk_score" ]] && [[ "$risk_score" =~ ^[0-9]+$ ]]; then
      if [[ $risk_score -le 25 ]]; then risk_tier="XS"
      elif [[ $risk_score -le 50 ]]; then risk_tier="STANDARD"
      elif [[ $risk_score -le 75 ]]; then risk_tier="ENHANCED"
      else risk_tier="FULL"; fi
    fi
  fi
  local eff="$size_tier"
  if [[ -n "$risk_tier" ]]; then
    local -A rank=([XS]=0 [STANDARD]=1 [ENHANCED]=2 [FULL]=3)
    if [[ ${rank[$risk_tier]:-0} -gt ${rank[$size_tier]:-0} ]]; then
      eff="$risk_tier"
      escalated=", risk score $risk_score escalated from $size_tier"
    fi
  fi
  case "$eff" in
    XS)       echo "XS ($size lines${escalated}) — quick lint" ;;
    STANDARD) echo "WARN: Review level: STANDARD ($size lines${escalated}) — 1 reviewer recommended" ;;
    ENHANCED) echo "WARN: Review level: ENHANCED ($size lines${escalated}) — 2 reviewers + architect recommended" ;;
    FULL)     echo "WARN: Review level: FULL ($size lines${escalated}) — consensus panel recommended. Consider splitting." ;;
  esac
}
