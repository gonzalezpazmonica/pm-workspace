#!/bin/bash
set -uo pipefail
# token-estimator.sh — SPEC-069-TOKEN: Estimate token cost before execution
# Inspired by pCompiler cost estimator. Pre-calculates tokens without calling LLM.
# Usage: token-estimator.sh [file|dir] [--budget N] [--model opus|sonnet|haiku]
#
# Token estimation: chars / 4 (industry standard approximation)
# Pricing: per 1M tokens (input) — Opus $15, Sonnet $3, Haiku $0.80

TARGET="${1:-.}"
BUDGET=""
MODEL="opus"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --budget) BUDGET="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

# Pricing per 1M input tokens (USD, April 2026)
declare -A PRICE_PER_M=([opus]=15.00 [sonnet]=3.00 [haiku]=0.80)
PRICE=${PRICE_PER_M[$MODEL]:-15.00}

estimate_tokens() {
  local file="$1"
  local chars
  chars=$(wc -c < "$file" 2>/dev/null || echo 0)
  echo $(( chars / 4 ))
}

# Single file
if [[ -f "$TARGET" ]]; then
  TOKENS=$(estimate_tokens "$TARGET")
  COST=$(awk "BEGIN {printf \"%.4f\", $TOKENS * $PRICE / 1000000}")
  echo "File: $TARGET"
  echo "Tokens: $TOKENS (~$(wc -c < "$TARGET") chars)"
  echo "Model: $MODEL | Cost: \$$COST"
  if [[ -n "$BUDGET" ]] && [[ "$TOKENS" -gt "$BUDGET" ]]; then
    echo "WARNING: exceeds budget of $BUDGET tokens by $((TOKENS - BUDGET))"
    exit 1
  fi
  exit 0
fi

# Directory — aggregate
if [[ -d "$TARGET" ]]; then
  TOTAL_TOKENS=0
  TOTAL_FILES=0
  MAX_FILE=""
  MAX_TOKENS=0

  while IFS= read -r -d '' file; do
    tokens=$(estimate_tokens "$file")
    TOTAL_TOKENS=$((TOTAL_TOKENS + tokens))
    TOTAL_FILES=$((TOTAL_FILES + 1))
    if [[ "$tokens" -gt "$MAX_TOKENS" ]]; then
      MAX_TOKENS=$tokens
      MAX_FILE="$file"
    fi
  done < <(find "$TARGET" -maxdepth 3 -type f \( -name "*.md" -o -name "*.sh" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.ts" -o -name "*.py" -o -name "*.cs" -o -name "*.go" -o -name "*.rs" \) -print0 2>/dev/null)

  COST=$(awk "BEGIN {printf \"%.4f\", $TOTAL_TOKENS * $PRICE / 1000000}")
  AVG=$((TOTAL_FILES > 0 ? TOTAL_TOKENS / TOTAL_FILES : 0))

  echo "Directory: $TARGET"
  echo "Files: $TOTAL_FILES | Total tokens: $TOTAL_TOKENS"
  echo "Average: $AVG tokens/file | Largest: $(basename "$MAX_FILE") ($MAX_TOKENS tokens)"
  echo "Model: $MODEL | Est. cost (full load): \$$COST"

  if [[ -n "$BUDGET" ]] && [[ "$TOTAL_TOKENS" -gt "$BUDGET" ]]; then
    OVER=$((TOTAL_TOKENS - BUDGET))
    echo "WARNING: exceeds budget of $BUDGET tokens by $OVER"
    echo "Suggestion: load only the top files needed, not the full directory"
    exit 1
  fi
  exit 0
fi

echo "Error: $TARGET not found" >&2
exit 2
