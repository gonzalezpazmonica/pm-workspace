#!/bin/bash
# tribunal-critic.sh — SE-201: quantitative scoring for tribunal verdicts
# Inspired by OpenHands Critic + IterativeRefinement pattern
# Ref: docs/propuestas/SE-201-critic-scoring.md
set -uo pipefail

THRESHOLD=${SAVIA_CRITIC_THRESHOLD:-80}
MAX_ITER=${SAVIA_CRITIC_MAX_ITERATIONS:-3}
SCORES_DIR="${SAVIA_CRITIC_SCORES_DIR:-${PROJECT_ROOT:-$(pwd)}/.savia}"
SCORES_FILE="$SCORES_DIR/tribunal-scores.jsonl"

# ── Argument parsing ────────────────────────────────────────────────────────

RUBRIC_FILE=""
JSON_OUTPUT=false
VERDICT_FILE=""

usage() {
  echo "Usage: tribunal-critic.sh [--rubric <file>] [--json] <verdict_file>" >&2
  echo "" >&2
  echo "  --rubric <file>   Custom rubric in JSON format" >&2
  echo "  --json            Output JSON (default: human-readable)" >&2
  echo "" >&2
  echo "Env vars:" >&2
  echo "  SAVIA_CRITIC_THRESHOLD       Pass threshold 0-100 (default: 80)" >&2
  echo "  SAVIA_CRITIC_MAX_ITERATIONS  Max refinement iterations (default: 3)" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rubric)
      RUBRIC_FILE="${2:-}"
      shift 2
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    -*)
      echo "ERROR: Unknown flag: $1" >&2
      usage
      ;;
    *)
      VERDICT_FILE="$1"
      shift
      ;;
  esac
done

# ── Validation ──────────────────────────────────────────────────────────────

if [[ -z "$VERDICT_FILE" ]]; then
  echo "ERROR: <verdict_file> argument required" >&2
  usage
fi

if [[ ! -f "$VERDICT_FILE" ]]; then
  echo "ERROR: verdict file not found: $VERDICT_FILE" >&2
  exit 1
fi

# ── Rubric loading ──────────────────────────────────────────────────────────

# Default rubric weights (each dimension = 25 points max)
WEIGHT_CORRECTNESS=25
WEIGHT_COMPLETENESS=25
WEIGHT_SECURITY=25
WEIGHT_SPEC_COMPLIANCE=25

if [[ -n "$RUBRIC_FILE" ]]; then
  if [[ ! -f "$RUBRIC_FILE" ]]; then
    echo "ERROR: rubric file not found: $RUBRIC_FILE" >&2
    exit 1
  fi
  # Parse JSON rubric if python3 available
  if command -v python3 >/dev/null 2>&1; then
    WEIGHT_CORRECTNESS=$(python3 -c "
import json, sys
try:
    r = json.load(open('$RUBRIC_FILE'))
    print(r.get('correctness', 25))
except Exception as e:
    print(25)
" 2>/dev/null)
    WEIGHT_COMPLETENESS=$(python3 -c "
import json, sys
try:
    r = json.load(open('$RUBRIC_FILE'))
    print(r.get('completeness', 25))
except Exception as e:
    print(25)
" 2>/dev/null)
    WEIGHT_SECURITY=$(python3 -c "
import json, sys
try:
    r = json.load(open('$RUBRIC_FILE'))
    print(r.get('security', 25))
except Exception as e:
    print(25)
" 2>/dev/null)
    WEIGHT_SPEC_COMPLIANCE=$(python3 -c "
import json, sys
try:
    r = json.load(open('$RUBRIC_FILE'))
    print(r.get('spec_compliance', 25))
except Exception as e:
    print(25)
" 2>/dev/null)
  fi
fi

# ── Scoring heuristics ──────────────────────────────────────────────────────

CONTENT="$(cat "$VERDICT_FILE")"

# Handle empty file
if [[ -z "$CONTENT" ]]; then
  echo "ERROR: verdict file is empty: $VERDICT_FILE" >&2
  exit 1
fi

# correctness: PASS or positive score without CRITICAL
score_correctness=0
if echo "$CONTENT" | grep -qiE '\bPASS\b|verdict.*pass|✓|all.*pass|no.*blocker'; then
  score_correctness=$WEIGHT_CORRECTNESS
elif echo "$CONTENT" | grep -qiE '\bCRITICAL\b|FAIL|REJECT|blocker'; then
  score_correctness=0
else
  score_correctness=$(( WEIGHT_CORRECTNESS / 2 ))
fi

# completeness: ≥3 code areas mentioned
area_count=0
echo "$CONTENT" | grep -qiE '\bsecurity\b|\bauth\b|\bcredential\b' && (( area_count++ )) || true
echo "$CONTENT" | grep -qiE '\btest\b|\bcoverage\b|\bspec\b' && (( area_count++ )) || true
echo "$CONTENT" | grep -qiE '\bperformance\b|\bcomplexity\b|\bO\([nN]\)|\blatency\b' && (( area_count++ )) || true
echo "$CONTENT" | grep -qiE '\berror\b|\bexception\b|\bedge case\b|\bnull\b' && (( area_count++ )) || true
echo "$CONTENT" | grep -qiE '\bAPI\b|\binterface\b|\bcontract\b|\bschema\b' && (( area_count++ )) || true
echo "$CONTENT" | grep -qiE '\blogging\b|\bmonitoring\b|\btracing\b|\bmetric\b' && (( area_count++ )) || true

score_completeness=0
if [[ $area_count -ge 3 ]]; then
  score_completeness=$WEIGHT_COMPLETENESS
elif [[ $area_count -eq 2 ]]; then
  score_completeness=$(( WEIGHT_COMPLETENESS * 2 / 3 ))
elif [[ $area_count -eq 1 ]]; then
  score_completeness=$(( WEIGHT_COMPLETENESS / 3 ))
fi

# security: security/OWASP mention or explicit "no issues"
score_security=0
if echo "$CONTENT" | grep -qiE '\bOWASP\b|\bCWE\b|\binjection\b|\bXSS\b|\bCSRF\b'; then
  score_security=$WEIGHT_SECURITY
elif echo "$CONTENT" | grep -qiE '\bsecurity\b.*\bno issues\b|\bno security\b.*\bissue\b|security.*pass|security.*ok'; then
  score_security=$WEIGHT_SECURITY
elif echo "$CONTENT" | grep -qiE '\bsecurity\b'; then
  score_security=$(( WEIGHT_SECURITY * 2 / 3 ))
fi

# spec-compliance: spec or AC- or acceptance mentioned
score_spec=0
if echo "$CONTENT" | grep -qiE '\bAC-[0-9]+\b|\bacceptance criteria\b'; then
  score_spec=$WEIGHT_SPEC_COMPLIANCE
elif echo "$CONTENT" | grep -qiE '\bspec\b|\bSPEC-[0-9]+\b|\bSE-[0-9]+\b|\bacceptance\b'; then
  score_spec=$(( WEIGHT_SPEC_COMPLIANCE * 2 / 3 ))
fi

TOTAL_SCORE=$(( score_correctness + score_completeness + score_security + score_spec ))

# Clamp to 0-100
[[ $TOTAL_SCORE -gt 100 ]] && TOTAL_SCORE=100
[[ $TOTAL_SCORE -lt 0 ]]   && TOTAL_SCORE=0

PASS_BOOL="false"
[[ $TOTAL_SCORE -ge $THRESHOLD ]] && PASS_BOOL="true"

# ── Build feedback string ────────────────────────────────────────────────────

FEEDBACK_PARTS=()
[[ $score_correctness -lt $WEIGHT_CORRECTNESS ]] && FEEDBACK_PARTS+=("correctness: add explicit PASS/FAIL verdict and remove CRITICAL issues")
[[ $score_completeness -lt $WEIGHT_COMPLETENESS ]] && FEEDBACK_PARTS+=("completeness: cover ≥3 code areas (security, tests, errors, API, logging)")
[[ $score_security -lt $WEIGHT_SECURITY ]] && FEEDBACK_PARTS+=("security: mention OWASP/CWE categories or confirm no issues found")
[[ $score_spec -lt $WEIGHT_SPEC_COMPLIANCE ]] && FEEDBACK_PARTS+=("spec_compliance: reference AC-N or acceptance criteria explicitly")

if [[ ${#FEEDBACK_PARTS[@]} -eq 0 ]]; then
  FEEDBACK="All dimensions meet threshold."
else
  FEEDBACK="${FEEDBACK_PARTS[*]}"
  # Join with "; "
  FEEDBACK=$(IFS="; "; echo "${FEEDBACK_PARTS[*]}")
fi

# ── Log to output/tribunal-scores.jsonl ─────────────────────────────────────

mkdir -p "$SCORES_DIR"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
VERDICT_BASENAME="$(basename "$VERDICT_FILE")"

# Escape feedback for JSON
FEEDBACK_ESCAPED="${FEEDBACK//\"/\\\"}"

cat >> "$SCORES_FILE" <<EOF
{"timestamp":"$TIMESTAMP","verdict_file":"$VERDICT_BASENAME","score":$TOTAL_SCORE,"breakdown":{"correctness":$score_correctness,"completeness":$score_completeness,"security":$score_security,"spec_compliance":$score_spec},"pass":$PASS_BOOL,"threshold":$THRESHOLD,"feedback":"$FEEDBACK_ESCAPED"}
EOF

# ── Output ──────────────────────────────────────────────────────────────────

JSON_RESULT="{\"score\":$TOTAL_SCORE,\"breakdown\":{\"correctness\":$score_correctness,\"completeness\":$score_completeness,\"security\":$score_security,\"spec_compliance\":$score_spec},\"pass\":$PASS_BOOL,\"threshold\":$THRESHOLD,\"feedback\":\"$FEEDBACK_ESCAPED\"}"

if [[ "$JSON_OUTPUT" == true ]]; then
  echo "$JSON_RESULT"
else
  echo "=== Tribunal Critic Score (SE-201) ==="
  echo "Verdict: $VERDICT_FILE"
  echo ""
  echo "Correctness    : $score_correctness / $WEIGHT_CORRECTNESS"
  echo "Completeness   : $score_completeness / $WEIGHT_COMPLETENESS"
  echo "Security       : $score_security / $WEIGHT_SECURITY"
  echo "Spec-compliance: $score_spec / $WEIGHT_SPEC_COMPLIANCE"
  echo "─────────────────────────────────────"
  echo "Total          : $TOTAL_SCORE / 100  (threshold: $THRESHOLD)"
  echo "Result         : $([ "$PASS_BOOL" = "true" ] && echo PASS || echo FAIL)"
  echo ""
  echo "Feedback       : $FEEDBACK"
fi

# ── Exit codes ──────────────────────────────────────────────────────────────
# exit 0 = score >= threshold (pass)
# exit 1 = score < threshold (fail)

if [[ "$PASS_BOOL" == "true" ]]; then
  exit 0
else
  if [[ "$JSON_OUTPUT" != true ]]; then
    echo "" >&2
    echo "FAIL: score $TOTAL_SCORE < threshold $THRESHOLD" >&2
  else
    echo "{\"error\":\"score_below_threshold\",\"score\":$TOTAL_SCORE,\"threshold\":$THRESHOLD,\"feedback\":\"$FEEDBACK_ESCAPED\"}" >&2
  fi
  exit 1
fi
