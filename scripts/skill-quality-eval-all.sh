#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
# skill-quality-eval-all.sh — Batch evaluation of all skills (SE-278 S4)
#
# Evaluates every skill in .opencode/skills/ against the 8-dimension rubric.
# Uses content hash cache to skip unchanged skills.
# Produces aggregate report: output/skill-quality/batch-{date}.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SKILLS_DIR="${ROOT}/.opencode/skills"
EVAL_SCRIPT="${SCRIPT_DIR}/skill-quality-eval.sh"
OUTPUT_DIR="${ROOT}/output/skill-quality"

mkdir -p "$OUTPUT_DIR"

BATCH_DATE=$(date +%Y%m%d)
REPORT_FILE="${OUTPUT_DIR}/batch-${BATCH_DATE}.md"
JSON_FILE="${OUTPUT_DIR}/batch-${BATCH_DATE}.json"

die() { echo "ERROR: $*" >&2; exit 1; }
[[ -f "$EVAL_SCRIPT" ]] || die "skill-quality-eval.sh not found"
[[ -d "$SKILLS_DIR" ]] || die "Skills dir not found: $SKILLS_DIR"

extract_field() {
  local file="$1" field="$2"
  awk -v field="^${field}:" '
    /^---$/ { c++; if (c>=2) exit; next }
    c==1 {
      if ($0 ~ field) {
        sub(field, ""); sub(/^[[:space:]]+/, "")
        gsub(/^"|"$/, ""); print; exit
      }
    }
  ' "$file"
}

echo "==> Batch Skill Quality Evaluation"
echo "    Date: $(date)"
echo ""

# Collect all skill IDs
declare -a SKILL_IDS=()
while IFS= read -r f; do
  name=$(extract_field "$f" "name")
  [[ -z "$name" ]] && name=$(basename "$(dirname "$f")")
  [[ "$name" == "_template" ]] && continue
  SKILL_IDS+=("$name")
done < <(find -L "${SKILLS_DIR}" -mindepth 2 -maxdepth 4 -name "SKILL.md" -type f ! -path '*/_template/*' | LC_ALL=C sort)

TOTAL=${#SKILL_IDS[@]}
echo "    Skills to evaluate: $TOTAL"
echo ""

PASS_COUNT=0; WARN_COUNT=0; BLOCK_COUNT=0; ERROR_COUNT=0; CACHED_COUNT=0
declare -a RESULTS=()

i=0
for skill_id in "${SKILL_IDS[@]}"; do
  i=$((i + 1))
  printf "    [%3d/%3d] %-40s " "$i" "$TOTAL" "$skill_id"

  result=$(bash "$EVAL_SCRIPT" "$skill_id" 2>/dev/null || echo '{"error":"eval failed"}')

  if echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('cached') else 1)" 2>/dev/null; then
    echo "CACHED"
    CACHED_COUNT=$((CACHED_COUNT + 1))
    score=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total_score','?'))" 2>/dev/null)
    gate=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('gate','?'))" 2>/dev/null)
  elif echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('error') else 1)" 2>/dev/null; then
    echo "ERROR"
    ERROR_COUNT=$((ERROR_COUNT + 1))
    score="?"; gate="ERROR"
  else
    score=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total_score','?'))" 2>/dev/null)
    gate=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('gate','?'))" 2>/dev/null)
    case "$gate" in
      PASS) PASS_COUNT=$((PASS_COUNT + 1)); echo "$score PASS" ;;
      WARN) WARN_COUNT=$((WARN_COUNT + 1)); echo "$score WARN" ;;
      BLOCK) BLOCK_COUNT=$((BLOCK_COUNT + 1)); echo "$score BLOCK" ;;
      *) echo "$score $gate" ;;
    esac
  fi

  maturity=$(extract_field "${SKILLS_DIR}/${skill_id}/SKILL.md" "maturity")
  RESULTS+=("$(printf '%s|%s|%s|%s' "$skill_id" "$score" "$gate" "${maturity:-unknown}")")
done

# --- Generate batch report ---
{
  echo "# Batch Skill Quality Report"
  echo ""
  echo "**Date**: $(date +%Y-%m-%d) | **Evaluated**: $TOTAL skills"
  echo ""
  echo "## Summary"
  echo ""
  echo "| Gate | Count | % |"
  echo "|---|---|---|"
  printf "| PASS (>=8.5) | %d | %.0f%% |\n" "$PASS_COUNT" "$(python3 -c "print(round($PASS_COUNT*100/$TOTAL))" 2>/dev/null || echo 0)"
  printf "| WARN (7.0-8.4) | %d | %.0f%% |\n" "$WARN_COUNT" "$(python3 -c "print(round($WARN_COUNT*100/$TOTAL))" 2>/dev/null || echo 0)"
  printf "| BLOCK (<7.0) | %d | %.0f%% |\n" "$BLOCK_COUNT" "$(python3 -c "print(round($BLOCK_COUNT*100/$TOTAL))" 2>/dev/null || echo 0)"
  printf "| ERROR | %d | %.0f%% |\n" "$ERROR_COUNT" "$(python3 -c "print(round($ERROR_COUNT*100/$TOTAL))" 2>/dev/null || echo 0)"
  printf "| CACHED | %d | — |\n" "$CACHED_COUNT"
  echo ""

  # Top 10 and Bottom 10
  echo "## Top 10 Skills"
  echo ""
  echo "| Rank | Skill | Score | Gate | Maturity |"
  echo "|---|---|---|---|---|"

  # Sort by score descending
  printf '%s\n' "${RESULTS[@]}" | sort -t'|' -k2 -rn 2>/dev/null | head -10 | while IFS='|' read -r name score gate maturity; do
    echo "| | $name | $score | $gate | $maturity |"
  done

  echo ""
  echo "## Bottom 10 Skills"
  echo ""
  echo "| Rank | Skill | Score | Gate | Maturity |"
  echo "|---|---|---|---|---|"

  printf '%s\n' "${RESULTS[@]}" | sort -t'|' -k2 -n 2>/dev/null | head -10 | while IFS='|' read -r name score gate maturity; do
    echo "| | $name | $score | $gate | $maturity |"
  done

  echo ""
  echo "## All Results"
  echo ""
  echo "| Skill | Score | Gate | Maturity |"
  echo "|---|---|---|---|"
  for row in "${RESULTS[@]}"; do
    IFS='|' read -r name score gate maturity <<< "$row"
    echo "| $name | $score | $gate | $maturity |"
  done

} > "$REPORT_FILE"

# Generate JSON summary
python3 -c "
import json
results = []
for r in '''$(printf '%s\n' "${RESULTS[@]}")'''.strip().split('\n'):
    if r:
        parts = r.split('|')
        results.append({'skill': parts[0], 'score': parts[1], 'gate': parts[2], 'maturity': parts[3]})
summary = {
    'date': '$(date +%Y-%m-%d)',
    'total': $TOTAL,
    'pass': $PASS_COUNT,
    'warn': $WARN_COUNT,
    'block': $BLOCK_COUNT,
    'error': $ERROR_COUNT,
    'cached': $CACHED_COUNT,
    'results': results
}
with open('$JSON_FILE', 'w') as f:
    json.dump(summary, f, indent=2, ensure_ascii=False)
print(f'JSON written to $JSON_FILE')
" 2>/dev/null

echo ""
echo "    Report: $REPORT_FILE"
echo "    JSON:   $JSON_FILE"
echo ""
echo "    PASS: $PASS_COUNT  WARN: $WARN_COUNT  BLOCK: $BLOCK_COUNT  ERROR: $ERROR_COUNT  CACHED: $CACHED_COUNT"
