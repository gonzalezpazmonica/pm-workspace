#!/usr/bin/env bash
# context-task-classify.sh — SE-029 Slice 2 task-class classifier.
#
# Clasifica un turno de conversación en una de 6 clases de tarea, que
# determinan el ratio máximo de compresión permitido (ver SE-029 §2):
#
#   decision  → ratio ≤ 5:1  · frozen=true  (approvals, merges, commits)
#   spec      → ratio ≤ 3:1  · frozen=true  (SPEC-NNN, AC-MM, frontmatter)
#   code      → ratio ≤ 10:1 · frozen=parcial (diffs, tracebacks, fences)
#   review    → ratio ≤ 15:1 · (court findings, PASS/FAIL/WARN)
#   context   → ratio ≤ 25:1 · (explicaciones, markdown largo)
#   chitchat  → ratio ≤ 80:1 · (thanks, ok, si, saludos)
#
# Usage:
#   context-task-classify.sh --input turn.txt
#   context-task-classify.sh --input turn.txt --json
#   echo "text" | context-task-classify.sh --stdin
#
# Output (texto): "decision"
# Output (json):  {"class":"decision","max_ratio":5,"frozen":true,"score":{...}}
#
# Ref: SE-029 §2, SE-029-C (task-class classifier)
# Safety: read-only, set -uo pipefail.

set -uo pipefail

INPUT=""
STDIN=0
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 --input FILE         Classify the contents of FILE
  $0 --stdin              Classify stdin (pipe a turn in)
  $0 --input FILE --json  Emit JSON with class, max_ratio, frozen, score

Classes: decision | spec | code | review | context | chitchat
Ref: SE-029 §2 (SE-029-C)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --stdin) STDIN=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

if [[ "$STDIN" -eq 1 ]]; then
  TEXT=$(cat)
elif [[ -n "$INPUT" ]]; then
  [[ ! -f "$INPUT" ]] && { echo "ERROR: input file not found: $INPUT" >&2; exit 2; }
  TEXT=$(cat "$INPUT")
else
  usage; exit 2
fi

WORDS=$(echo "$TEXT" | wc -w | tr -d ' ')
LINES=$(echo "$TEXT" | wc -l | tr -d ' ')

# Scoring: each class gets a positive integer. Highest score wins.
# Ties broken by priority: decision > spec > code > review > context > chitchat
# (stricter classes first — err toward less compression).

score_decision=0
score_spec=0
score_code=0
score_review=0
score_context=0
score_chitchat=0

# decision: approvals, merges, commits, yes/no verdicts
echo "$TEXT" | grep -qiE '\b(approve|approved|approving|merge|merged|commit|decid[eoi]|decision:|ship it|lgtm|go ahead|bloqueado|aprobad[oa])\b' && score_decision=$((score_decision+3))
echo "$TEXT" | grep -qE '\b(APPROVED|MERGED|BLOCKED|SHIP)\b' && score_decision=$((score_decision+2))
echo "$TEXT" | grep -qE '^\s*(yes|no|si|sí|ok)\s*[.!]?$' && score_decision=$((score_decision+2))

# spec: SPEC-NNN, AC-MM, spec_id frontmatter
echo "$TEXT" | grep -qE 'SPEC-[0-9]+|SE-[0-9]+|PBI-[0-9]+' && score_spec=$((score_spec+3))
echo "$TEXT" | grep -qE 'AC-[0-9]+|acceptance criteria' && score_spec=$((score_spec+2))
echo "$TEXT" | grep -qE '^spec_id:|^status:|^origin:' && score_spec=$((score_spec+2))
echo "$TEXT" | grep -qE '^---$' && score_spec=$((score_spec+1))

# code: code fences, diff markers, tracebacks
echo "$TEXT" | grep -qE '^```' && score_code=$((score_code+3))
echo "$TEXT" | grep -qE '^\+\+\+|^---|^diff --git|^@@ ' && score_code=$((score_code+3))
echo "$TEXT" | grep -qiE 'Traceback|\bError:|Exception|stack trace|segmentation fault' && score_code=$((score_code+3))
echo "$TEXT" | grep -qE '^\s*(function|def|class|const|let|var|import)\s+\w+\s*[({:=]' && score_code=$((score_code+1))

# review: court findings, PASS/FAIL/WARN, judge verdicts
echo "$TEXT" | grep -qE '\b(PASS|FAIL|WARN|BLOCK|VERDICT):' && score_review=$((score_review+3))
echo "$TEXT" | grep -qiE 'judge|review finding|code review court|truth tribunal' && score_review=$((score_review+2))
echo "$TEXT" | grep -qE '\bG[0-9]+\s+(PASS|FAIL|WARN)' && score_review=$((score_review+2))
echo "$TEXT" | grep -qiE 'score: [0-9]+|auditor|certified' && score_review=$((score_review+1))

# context: long markdown, headings, bullet lists
echo "$TEXT" | grep -qE '^#{1,6} ' && score_context=$((score_context+1))
echo "$TEXT" | grep -qE '^\s*[-*] ' && score_context=$((score_context+1))
[[ "$WORDS" -gt 100 ]] && score_context=$((score_context+2))
[[ "$LINES" -gt 10 ]] && score_context=$((score_context+1))

# chitchat: very short, greetings, acknowledgements
[[ "$WORDS" -le 8 ]] && score_chitchat=$((score_chitchat+3))
echo "$TEXT" | grep -qiE '^\s*(thanks|gracias|thank you|ok|okay|perfect|bien|nice|cool|de nada)\s*[.!]?\s*$' && score_chitchat=$((score_chitchat+3))
echo "$TEXT" | grep -qiE '^\s*(hi|hello|hola|bye|adios|goodbye)' && score_chitchat=$((score_chitchat+2))

# Apply tie-breaking priority: if scores are equal, stricter class wins.
# We pick the max; in a tie, we walk the classes in stricter-first order.
best_class=""
best_score=-1
for pair in "decision:$score_decision" "spec:$score_spec" "code:$score_code" "review:$score_review" "context:$score_context" "chitchat:$score_chitchat"; do
  cls="${pair%:*}"
  sc="${pair#*:}"
  if [[ "$sc" -gt "$best_score" ]]; then
    best_class="$cls"
    best_score="$sc"
  fi
done

# Fallback: no signal at all → default to chitchat if very short, else context.
if [[ "$best_score" -le 0 ]]; then
  if [[ "$WORDS" -le 15 ]]; then
    best_class="chitchat"
  else
    best_class="context"
  fi
fi

# Derive max_ratio and frozen flag.
case "$best_class" in
  decision) max_ratio=5;  frozen=true ;;
  spec)     max_ratio=3;  frozen=true ;;
  code)     max_ratio=10; frozen=partial ;;
  review)   max_ratio=15; frozen=false ;;
  context)  max_ratio=25; frozen=false ;;
  chitchat) max_ratio=80; frozen=false ;;
esac

if [[ "$JSON" -eq 1 ]]; then
  cat <<JSON
{"class":"$best_class","max_ratio":$max_ratio,"frozen":"$frozen","words":$WORDS,"lines":$LINES,"scores":{"decision":$score_decision,"spec":$score_spec,"code":$score_code,"review":$score_review,"context":$score_context,"chitchat":$score_chitchat}}
JSON
else
  echo "$best_class"
fi

exit 0
