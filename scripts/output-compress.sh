#!/usr/bin/env bash
set -uo pipefail
# output-compress.sh — Compress verbose tool output (stdin -> stdout)
# Usage: echo "$OUTPUT" | output-compress.sh [--command CMD] [--max-lines N]
# Exit: 0 always (failure = pass through)

CMD_HINT="generic"; MAX_LINES=50
while [[ $# -gt 0 ]]; do
  case "$1" in
    --command) CMD_HINT="$2"; shift 2 ;; --max-lines) MAX_LINES="$2"; shift 2 ;; *) shift ;;
  esac
done
[[ $MAX_LINES -lt 10 ]] && MAX_LINES=10; [[ $MAX_LINES -gt 200 ]] && MAX_LINES=200

INPUT=$(cat); [[ -z "$INPUT" ]] && exit 0
ORIG_LINES=$(printf '%s\n' "$INPUT" | wc -l)

# Step 1: Strip ANSI codes
CLEAN=$(printf '%s\n' "$INPUT" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')

# Step 2: Remove \r artifacts and progress lines
CLEAN=$(printf '%s\n' "$CLEAN" | tr -d '\r' | grep -v '^[[:space:]]*[|/\-]*[[:space:]]*$' || true)

# Step 3: Collapse consecutive blank lines
CLEAN=$(printf '%s\n' "$CLEAN" | awk 'NF{blank=0;print;next}{blank++;if(blank<=1)print}')

# Step 4: Deduplicate consecutive identical lines
CLEAN=$(printf '%s\n' "$CLEAN" | awk '
  prev==$0{cnt++;next}
  cnt>0{print prev" [...repeated "cnt+1" times]";cnt=0}
  {if(prev!="")print prev;prev=$0}
  END{if(cnt>0)print prev" [...repeated "cnt+1" times]";else if(prev!="")print prev}')

# Step 5: Truncate stack traces EARLY (before command filter strips them)
CLEAN=$(printf '%s\n' "$CLEAN" | awk '
  /^   at /{frames[++fc]=$0;next}
  fc>0{
    if(fc<=4)for(i=1;i<=fc;i++)print frames[i]
    else{print frames[1];print frames[2];print "   [... "fc-4" frames omitted]";print frames[fc-1];print frames[fc]}
    fc=0;delete frames
  }
  {print}
  END{if(fc>0){if(fc<=4)for(i=1;i<=fc;i++)print frames[i];else{print frames[1];print frames[2];print "   [... "fc-4" frames omitted]";print frames[fc-1];print frames[fc]}}}')

# Pass through short output (<=30 lines after dedup+stack truncation)
CURRENT_LINES=$(printf '%s\n' "$CLEAN" | wc -l)
if [[ $CURRENT_LINES -le 30 ]]; then printf '%s\n' "$CLEAN"; exit 0; fi

# Step 6: Command-specific filter
filter_result=""
case "$CMD_HINT" in
  *"git log"*)
    filter_result=$(printf '%s\n' "$CLEAN" | grep -E '^[a-f0-9]{7,} ' || printf '%s\n' "$CLEAN" | grep -E '^(commit [a-f0-9]|    [^ ])' | sed 's/^commit //' | sed 's/^    //') ;;
  *"git diff"*)
    filter_result=$(printf '%s\n' "$CLEAN" | grep -E '^(diff |---|\+\+\+|@@|[+-])') ;;
  *"git status"*)
    filter_result=$(printf '%s\n' "$CLEAN" | grep -E '(modified:|new file:|deleted:|renamed:|Untracked|^\?\?)' | sed 's/^#[[:space:]]*//' ) ;;
  *"dotnet test"*)
    # Summary + failures first (survive truncation), then individual results
    local_summary=$(printf '%s\n' "$CLEAN" | grep -iE '(Failed!|Total:|test result|Tests run)' || true)
    local_failures=$(printf '%s\n' "$CLEAN" | grep -iE '(Failed |Error |✗ |Assert|frames omitted)' | grep -ivE '^[[:space:]]*(Passed|Total:)' || true)
    local_passed=$(printf '%s\n' "$CLEAN" | grep -iE '(Passed )' | head -5 || true)
    filter_result="${local_summary}"
    [[ -n "$local_failures" ]] && filter_result="${filter_result}
${local_failures}"
    [[ -n "$local_passed" ]] && filter_result="${filter_result}
${local_passed}
  [...and more passed tests]"
    filter_result=$(printf '%s\n' "$filter_result" | sed '/^$/d') ;;
  *"dotnet build"*)
    filter_result=$(printf '%s\n' "$CLEAN" | grep -iE '(: error |: warning |Build succeeded|Build FAILED|succeeded|failed)') ;;
  *"validate-ci"*)
    filter_result=$(printf '%s\n' "$CLEAN" | grep -iE '(PASS|FAIL|WARN|safe to push|STOPPED)') ;;
  *"npm "*|*"pnpm "*)
    filter_result=$(printf '%s\n' "$CLEAN" | grep -ivE '(^\s*$|npm warn|added [0-9]+ packages|up to date|audited|progress)') ;;
esac
[[ -n "$filter_result" ]] && CLEAN="$filter_result"

# Step 7: Group similar warnings (3+ identical warning codes)
CLEAN=$(printf '%s\n' "$CLEAN" | awk '{
  if(match($0,/warning [A-Z]+[0-9]+/)){
    code=substr($0,RSTART+8,RLENGTH-8); warns[code]++; next
  } print
} END{for(c in warns)if(warns[c]>=3)print "warning "c" (x"warns[c]")"; else for(i=1;i<=warns[c];i++)print "warning "c}')

# Step 8: Cap at max-lines with footer
RESULT_LINES=$(printf '%s\n' "$CLEAN" | wc -l)
if [[ $RESULT_LINES -gt $MAX_LINES ]]; then
  CLEAN=$(printf '%s\n' "$CLEAN" | head -$((MAX_LINES - 1)))
  SAVED=$(( (ORIG_LINES - MAX_LINES + 1) * 20 / 4 ))
  CLEAN="${CLEAN}
[... ${ORIG_LINES} lines -> ${MAX_LINES} lines, ~${SAVED} tokens saved]"
fi

printf '%s\n' "$CLEAN"
exit 0
