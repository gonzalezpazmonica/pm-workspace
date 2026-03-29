#!/usr/bin/env bash
set -uo pipefail
# review-depth-selector.sh — Select review depth based on risk score
# Usage: review-depth-selector.sh <risk-score>
# Output: depth, model, and perspectives as structured text.
# Aligned with risk-escalation.md thresholds:
#   0-25  → quick   (Low)
#   26-50 → standard (Medium)
#   51-75 → thorough (High)
#   76-100 → thorough (Critical)
# Phase 1 of SPEC-049 Depth-Adjustable Review.

SCORE="${1:-}"

if [[ -z "$SCORE" ]]; then
  echo "ERROR: Usage: review-depth-selector.sh <risk-score>"
  echo "  risk-score: integer 0-100"
  exit 1
fi

# Validate numeric
if ! [[ "$SCORE" =~ ^[0-9]+$ ]]; then
  echo "ERROR: risk-score must be a non-negative integer, got: $SCORE"
  exit 1
fi

if [[ "$SCORE" -gt 100 ]]; then
  echo "ERROR: risk-score must be 0-100, got: $SCORE"
  exit 1
fi

# Depth selection based on risk-escalation.md thresholds
if [[ "$SCORE" -le 25 ]]; then
  DEPTH="quick"
  MODEL="haiku"
  PERSPECTIVES="syntax,conventions"
  TIMELINE="expedited"
  REVIEWERS="auto-merge + spot-check"
elif [[ "$SCORE" -le 50 ]]; then
  DEPTH="standard"
  MODEL="sonnet"
  PERSPECTIVES="syntax,conventions,logic,security"
  TIMELINE="24h"
  REVIEWERS="1 reviewer (Code Review E1)"
elif [[ "$SCORE" -le 75 ]]; then
  DEPTH="thorough"
  MODEL="opus"
  PERSPECTIVES="syntax,conventions,logic,security,architecture,performance"
  TIMELINE="48h"
  REVIEWERS="2 reviewers + architect"
else
  DEPTH="thorough"
  MODEL="opus"
  PERSPECTIVES="syntax,conventions,logic,security,architecture,performance,compliance"
  TIMELINE="72h"
  REVIEWERS="2 reviewers + architect + security + PM"
fi

echo "depth: $DEPTH"
echo "model: $MODEL"
echo "perspectives: $PERSPECTIVES"
echo "timeline: $TIMELINE"
echo "reviewers: $REVIEWERS"
echo "risk_score: $SCORE"
