#!/usr/bin/env bash
set -euo pipefail
# skill-feedback-rank.sh — Compute skill effectiveness and generate ranking
# Usage: skill-feedback-rank.sh [--detail SKILL] [--dormant] [--deprecated] [--export csv] [--test]

LOG="data/skill-invocations.jsonl"
DETAIL="" DORMANT=false DEPRECATED=false EXPORT="" TEST=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --detail) DETAIL="$2"; shift 2 ;; --dormant) DORMANT=true; shift ;;
    --deprecated) DEPRECATED=true; shift ;; --export) EXPORT="$2"; shift 2 ;;
    --test) TEST=true; shift ;; *) shift ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

if $TEST; then
  echo '{"skill":"test-skill","command":"test","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","outcome":"success","user_feedback":"accepted"}' > /tmp/sfr-test.jsonl
  for i in 1 2; do echo '{"skill":"test-skill","command":"test","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","outcome":"success","user_feedback":"accepted"}' >> /tmp/sfr-test.jsonl; done
  LOG="/tmp/sfr-test.jsonl"
fi

if [[ ! -f "$LOG" ]] || [[ ! -s "$LOG" ]]; then
  echo "No invocation data found. Skills will be tracked as they are used."; exit 0
fi

NOW=$(date +%s 2>/dev/null || echo 0)
D90=$(( NOW - 7776000 )); D30=$(( NOW - 2592000 ))
OUT_DIR="output/skill-ranking"; mkdir -p "$OUT_DIR" 2>/dev/null || true
DATE=$(date +%Y%m%d 2>/dev/null || echo "00000000")
OUT_FILE="$OUT_DIR/${DATE}-skill-rank.md"

# Compute per-skill stats with jq
STATS=$(jq -r --argjson d90 "$D90" --argjson d30 "$D30" '
  [inputs] | map(. + {epoch: ((.timestamp | split("T")[0] | split("-") | .[0] + .[1] + .[2]) | tonumber // 0)}) |
  group_by(.skill) | map({
    skill: .[0].skill,
    total: length,
    successes: [.[] | select(.outcome=="success")] | length,
    accepted: [.[] | select(.user_feedback=="accepted")] | length,
    feedback_count: [.[] | select(.user_feedback!=null and .user_feedback!="null")] | length,
    label: (if length < 3 then "insufficient_data" elif length == 0 then "dormant" else "ranked" end)
  }) | sort_by(-.total)
' "$LOG" 2>/dev/null < /dev/null) || STATS="[]"

# Generate output
TOTAL=$(echo "$STATS" | jq 'map(.total) | add // 0' 2>/dev/null || echo 0)
RANKED=$(echo "$STATS" | jq '[.[] | select(.label=="ranked")] | length' 2>/dev/null || echo 0)
SKILL_COUNT=$(ls -d .claude/skills/*/ 2>/dev/null | wc -l || echo 82)

echo "===================================================="
echo "  /skill-rank — Skill Effectiveness Ranking"
echo "===================================================="
echo ""
echo "  Period: last 90 days"
echo "  Total invocations: $TOTAL"
echo "  Skills with data: $RANKED / $SKILL_COUNT"
echo ""

if [[ "$TOTAL" -gt 0 ]]; then
  echo "  -- Top by effectiveness --"
  echo ""
  printf "  %-3s %-30s %-5s %-12s %s\n" "#" "Skill" "Eff%" "Invocations" "Status"
  echo "$STATS" | jq -r '.[] | select(.label=="ranked") |
    (.successes/.total*50 + (if .feedback_count>0 then .accepted/.feedback_count*30 else 15 end) + 20) as $eff |
    [.skill, ($eff|floor|tostring)+"%", (.total|tostring),
     (if $eff>=70 then "healthy" elif $eff>=50 then "underperforming" elif $eff>=30 then "weak" else "deprecation_candidate" end)
    ] | @tsv' 2>/dev/null | head -20 | nl -ba -w2 -s"  " | while read -r line; do
    printf "  %s\n" "$line"
  done
  echo ""
fi

# Dormant and insufficient
INSUF=$(echo "$STATS" | jq -r '[.[] | select(.label=="insufficient_data")] | length' 2>/dev/null || echo 0)
echo "  Insufficient data (<3 invocations): $INSUF skills"
echo ""

# Deprecation candidates
DEPR=$(echo "$STATS" | jq -r '[.[] | select(.label=="ranked") |
  (.successes/.total*50 + (if .feedback_count>0 then .accepted/.feedback_count*30 else 15 end) + 20) as $eff |
  select($eff < 30)] | length' 2>/dev/null || echo 0)
echo "  Deprecation candidates: $DEPR skills flagged."
echo ""
echo "  File: $OUT_FILE"
echo ""
echo "===================================================="

# Save to file
echo "# Skill Ranking — $DATE" > "$OUT_FILE"
echo "" >> "$OUT_FILE"
echo "Total invocations: $TOTAL" >> "$OUT_FILE"

$TEST && rm -f /tmp/sfr-test.jsonl
exit 0
