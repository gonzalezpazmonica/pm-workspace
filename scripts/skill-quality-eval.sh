#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
# skill-quality-eval.sh — Semantic skill quality evaluation via LLM judge (SE-278)
#
# Evaluates a single SKILL.md against the 8-dimension rubric.
# Phases:
#   1. Load rubric from scripts/skill-quality-rubric.yaml
#   2. Load skill content from .opencode/skills/<id>/SKILL.md
#   3. Check content hash cache (skip if unchanged)
#   4. Invoke LLM judge via savia-dual (cloud or local)
#   5. Parse JSON output, compute weighted score
#   6. Apply gate (PASS/WARN/BLOCK)
#   7. Write report to output/skill-quality/<id>-<date>.json
#
# Usage: skill-quality-eval.sh <skill-id> [--force] [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SKILLS_DIR="${ROOT}/.opencode/skills"
RUBRIC_FILE="${SCRIPT_DIR}/skill-quality-rubric.yaml"
CACHE_DIR="${ROOT}/output/skill-quality/cache"
OUTPUT_DIR="${ROOT}/output/skill-quality"
PASS_THRESHOLD="${SKILL_QUALITY_PASS_THRESHOLD:-8.5}"
BLOCK_THRESHOLD="${SKILL_QUALITY_BLOCK_THRESHOLD:-7.0}"

die() { echo "ERROR: $*" >&2; exit 1; }

SKILL_ID="${1:-}"
FORCE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h)
      echo "Usage: skill-quality-eval.sh <skill-id> [--force] [--dry-run]"
      exit 0
      ;;
    *) SKILL_ID="$1"; shift ;;
  esac
done

[[ -z "$SKILL_ID" ]] && die "skill-id required"
[[ -f "$RUBRIC_FILE" ]] || die "Rubric file not found: $RUBRIC_FILE"

SKILL_FILE="${SKILLS_DIR}/${SKILL_ID}/SKILL.md"
[[ -f "$SKILL_FILE" ]] || die "Skill not found: $SKILL_FILE"

mkdir -p "$CACHE_DIR" "$OUTPUT_DIR"

# --- Phase 1: Content hash for cache ---
CONTENT_HASH=$(sha256sum "$SKILL_FILE" | cut -d' ' -f1)
CACHE_FILE="${CACHE_DIR}/${SKILL_ID}-${CONTENT_HASH}.json"

if [[ -f "$CACHE_FILE" ]] && ! $FORCE; then
  echo "{\"skill_id\":\"$SKILL_ID\",\"cached\":true,\"hash\":\"$CONTENT_HASH\"}"
  cat "$CACHE_FILE"
  exit 0
fi

# --- Phase 2: Load rubric YAML ---
RUBRIC_YAML=$(cat "$RUBRIC_FILE")
SKILL_CONTENT=$(cat "$SKILL_FILE")

# Build judge prompt
JUDGE_PROMPT=$(cat <<PROMPT
Eres un juez de calidad de skills para Savia (pm-workspace).
Evalua la siguiente SKILL.md contra la rubrica de 8 dimensiones.

RUBRICA:
$RUBRIC_YAML

SKILL A EVALUAR (${SKILL_ID}):
$SKILL_CONTENT

Emite UNICAMENTE un objeto JSON con este formato exacto (sin markdown, sin texto adicional):
{
  "skill_id": "${SKILL_ID}",
  "content_hash": "${CONTENT_HASH}",
  "evaluation": {
    "clarity": {"score": N, "evidence": "...", "suggestion": "..."},
    "completeness": {"score": N, "evidence": "...", "suggestion": "..."},
    "actionability": {"score": N, "evidence": "...", "suggestion": "..."},
    "correctness": {"score": N, "evidence": "...", "suggestion": "..."},
    "conciseness": {"score": N, "evidence": "...", "suggestion": "..."},
    "safety": {"score": N, "evidence": "...", "suggestion": "..."},
    "freshness": {"score": N, "evidence": "...", "suggestion": "..."},
    "testability": {"score": N, "evidence": "...", "suggestion": "..."}
  },
  "total_score": N.N,
  "gate": "PASS|WARN|BLOCK",
  "summary": "Resumen en 1-2 frases en español"
}

Reglas:
- Cada score es 0-10 (entero o .5)
- total_score = (clarity*1.5 + completeness*1.5 + actionability*2.0 + correctness*2.0 + conciseness*1.0 + safety*1.5 + freshness*0.5 + testability*1.0) / 11.0
- Redondea total_score a 1 decimal
- gate: >=${PASS_THRESHOLD} → PASS, ${BLOCK_THRESHOLD}-${PASS_THRESHOLD} → WARN, <${BLOCK_THRESHOLD} → BLOCK
- evidence: 1 frase citando partes concretas de la skill
- suggestion: 1 frase con mejora accionable (o "N/A" si score >= 9)
- NO emitas markdown, solo JSON
PROMPT
)

if $DRY_RUN; then
  echo "{\"skill_id\":\"$SKILL_ID\",\"hash\":\"$CONTENT_HASH\",\"dry_run\":true,\"prompt_size\":${#JUDGE_PROMPT}}"
  exit 0
fi

# --- Phase 3: Invoke LLM judge ---
# Try savia-dual (cloud Anthropic), fallback to direct API call
EVAL_OUTPUT=""

# Try via savia-dual if available
if command -v savia-dual &>/dev/null; then
  EVAL_OUTPUT=$(echo "$JUDGE_PROMPT" | savia-dual --model mid --json --timeout 120 2>/dev/null || true)
fi

# Fallback: direct API call via curl to Anthropic API
if [[ -z "$EVAL_OUTPUT" ]]; then
  ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
  if [[ -n "$ANTHROPIC_API_KEY" ]]; then
    EVAL_OUTPUT=$(curl -s https://api.anthropic.com/v1/messages \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d "$(python3 -c "
import json, sys
print(json.dumps({
  'model': 'claude-3-5-haiku-20241022',
  'max_tokens': 1024,
  'messages': [{'role': 'user', 'content': '''${JUDGE_PROMPT//\'/\'\\\'\'}'''}]
}))
" 2>/dev/null)" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['content'][0]['text'])
" 2>/dev/null || true)
  fi
fi

# --- Phase 4: Parse and validate ---
if [[ -z "$EVAL_OUTPUT" ]]; then
  echo "{\"skill_id\":\"$SKILL_ID\",\"error\":\"LLM judge unavailable — try with ANTHROPIC_API_KEY set or savia-dual installed\",\"hash\":\"$CONTENT_HASH\"}"
  exit 1
fi

# Extract JSON from possibly markdown-wrapped output
JSON_OUTPUT=$(echo "$EVAL_OUTPUT" | python3 -c "
import sys, json, re
text = sys.stdin.read()
# Try to find JSON block
match = re.search(r'\{[\s\S]*\}', text)
if match:
    try:
        d = json.loads(match.group())
        # Recalculate total_score to validate
        e = d.get('evaluation', {})
        weights = {'clarity': 1.5, 'completeness': 1.5, 'actionability': 2.0,
                   'correctness': 2.0, 'conciseness': 1.0, 'safety': 1.5,
                   'freshness': 0.5, 'testability': 1.0}
        total = sum(e.get(dim, {}).get('score', 0) * w for dim, w in weights.items())
        computed = round(total / 11.0, 1)
        d['total_score'] = computed
        d['gate'] = 'PASS' if computed >= $PASS_THRESHOLD else ('WARN' if computed >= $BLOCK_THRESHOLD else 'BLOCK')
        print(json.dumps(d, indent=2, ensure_ascii=False))
    except Exception as ex:
        print(json.dumps({'error': f'JSON parse failed: {ex}', 'raw': text[:500]}))
else:
    print(json.dumps({'error': 'No JSON found in output', 'raw': text[:500]}))
" 2>/dev/null)

if [[ -z "$JSON_OUTPUT" ]]; then
  echo "{\"skill_id\":\"$SKILL_ID\",\"error\":\"Failed to parse judge output\",\"raw_head\":\"${EVAL_OUTPUT:0:200}\"}"
  exit 1
fi

# --- Phase 5: Cache and report ---
echo "$JSON_OUTPUT" > "$CACHE_FILE"

# Also write a human-readable markdown report
REPORT_DATE=$(date +%Y%m%d)
REPORT_FILE="${OUTPUT_DIR}/${SKILL_ID}-${REPORT_DATE}.md"
TOTAL_SCORE=$(echo "$JSON_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total_score','N/A'))" 2>/dev/null || echo "N/A")
GATE=$(echo "$JSON_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('gate','N/A'))" 2>/dev/null || echo "N/A")

{
  echo "# Skill Quality Report: \`$SKILL_ID\`"
  echo ""
  echo "**Date**: $(date +%Y-%m-%d) | **Score**: $TOTAL_SCORE/10 | **Gate**: $GATE"
  echo "**Hash**: \`$CONTENT_HASH\`"
  echo ""
  echo "## Dimension Scores"
  echo ""
  echo "| Dimension | Score | Evidence | Suggestion |"
  echo "|---|---|---|---|"
  echo "$JSON_OUTPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for dim, info in d.get('evaluation', {}).items():
    s = info.get('score', '?')
    ev = info.get('evidence', '—')
    sug = info.get('suggestion', '—')
    print(f'| {dim} | {s} | {ev} | {sug} |')
" 2>/dev/null
  echo ""
  echo "## Summary"
  echo ""
  SUMMARY=$(echo "$JSON_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('summary',''))" 2>/dev/null || echo "N/A")
  echo "$SUMMARY"
} > "$REPORT_FILE"

echo "$JSON_OUTPUT"
exit 0
