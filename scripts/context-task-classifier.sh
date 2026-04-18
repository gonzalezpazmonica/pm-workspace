#!/usr/bin/env bash
# context-task-classifier.sh — SE-029-C
# Classifies a conversation turn into a task-class and returns the
# max compression ratio allowed for that class.
# Ref: docs/propuestas/SE-029-rate-distortion-context.md
#
# Usage:
#   bash scripts/context-task-classifier.sh --input FILE [--json]
#   echo "text" | bash scripts/context-task-classifier.sh [--json]
#
# Classes (with max ratio):
#   decision  5:1   frozen=yes  — approvals, merge, commits
#   spec      3:1   frozen=yes  — SPEC-NNN, AC-
#   code      10:1  frozen=partial — diffs, stack traces
#   review    15:1  frozen=no   — code review findings
#   context   25:1  frozen=no   — explanations, docs
#   chitchat  80:1  frozen=no   — small talk

set -uo pipefail

INPUT_FILE=""
JSON_OUT=false
INPUT=""

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT_FILE="$2"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag $1" >&2; exit 2 ;;
  esac
done

if [[ -n "$INPUT_FILE" ]]; then
  [[ ! -f "$INPUT_FILE" ]] && { echo "Error: file not found: $INPUT_FILE" >&2; exit 2; }
  INPUT=$(cat "$INPUT_FILE")
else
  if [[ -t 0 ]]; then
    echo "Error: no input (stdin empty and no --file)" >&2
    exit 2
  fi
  INPUT=$(cat)
fi

[[ -z "$INPUT" ]] && { echo "Error: empty input" >&2; exit 2; }

# ── Classification rules (priority order) ────────────────────────────────────
# Higher priority = more restrictive class

CLASS=""
CONFIDENCE="heuristic"

# Decision: approvals, merge, commits, final verdicts
if echo "$INPUT" | grep -qiE "\b(approve|approved|merged?|commit|PR #[0-9]+|decision:|decided)\b"; then
  CLASS="decision"
# Spec: SPEC-NNN references or Acceptance Criteria
elif echo "$INPUT" | grep -qE "\bSPEC-[0-9]+|AC-[0-9]+|acceptance criteria"; then
  CLASS="spec"
# Code: diffs, stack traces, error output
elif echo "$INPUT" | grep -qE "^diff --git|^@@|Traceback|^Error:|^\s+at [a-zA-Z]+\.|^\+\+\+|^---"; then
  CLASS="code"
# Review: code review language
elif echo "$INPUT" | grep -qiE "\b(review|finding|issue:|vulnerability|bug|defect|lgtm|nitpick)\b"; then
  CLASS="review"
# Chitchat: very short, thanks/ack
elif [[ "$(echo "$INPUT" | wc -w)" -le 6 ]] && echo "$INPUT" | grep -qiE "^\s*(thanks|thx|ok|great|cool|lgtm|ack|nice|bien|gracias|vale)"; then
  CLASS="chitchat"
# Context: default for explanation/docs-like text
else
  CLASS="context"
fi

# ── Ratio + frozen table ─────────────────────────────────────────────────────
declare -A MAX_RATIO=(
  [decision]=5
  [spec]=3
  [code]=10
  [review]=15
  [context]=25
  [chitchat]=80
)
declare -A FROZEN=(
  [decision]="yes"
  [spec]="yes"
  [code]="partial"
  [review]="no"
  [context]="no"
  [chitchat]="no"
)

RATIO=${MAX_RATIO[$CLASS]}
FROZEN_VAL=${FROZEN[$CLASS]}

# ── Output ───────────────────────────────────────────────────────────────────
if $JSON_OUT; then
  printf '{"class":"%s","max_ratio":%d,"frozen":"%s","confidence":"%s"}\n' \
    "$CLASS" "$RATIO" "$FROZEN_VAL" "$CONFIDENCE"
else
  echo "class:       $CLASS"
  echo "max_ratio:   ${RATIO}:1"
  echo "frozen:      $FROZEN_VAL"
  echo "confidence:  $CONFIDENCE"
fi
