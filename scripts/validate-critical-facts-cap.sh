#!/usr/bin/env bash
# scripts/validate-critical-facts-cap.sh
# SPEC-185: Validates docs/critical-facts.md is <= 150 tokens between markers.
# Exit 1 if cap exceeded; exit 0 if under cap.
# Token approximation: words * 1.3 (good for Spanish/English mixed text).

set -uo pipefail

FILE="${1:-docs/critical-facts.md}"
CAP="${CRITICAL_FACTS_TOKEN_CAP:-150}"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: $FILE not found" >&2
  exit 1
fi

# Verify markers exist
if ! grep -q "CRITICAL_FACTS_START" "$FILE" || ! grep -q "CRITICAL_FACTS_END" "$FILE"; then
  echo "ERROR: markers <!-- CRITICAL_FACTS_START --> / <!-- CRITICAL_FACTS_END --> not found in $FILE" >&2
  exit 1
fi

# Extract content between markers
CONTENT=$(awk '/<!-- CRITICAL_FACTS_START -->/{flag=1; next} /<!-- CRITICAL_FACTS_END -->/{flag=0} flag' "$FILE")

WORDS=$(echo "$CONTENT" | wc -w)
# Approximate token count: words * 1.3 (rounded up via integer math)
TOKENS=$(( (WORDS * 13 + 9) / 10 ))

if [[ "$TOKENS" -gt "$CAP" ]]; then
  echo "FAIL: $FILE has ~$TOKENS tokens ($WORDS words), cap=$CAP" >&2
  echo ""
  echo "Suggested removals (lowest priority first):"
  echo "  - Drop 'Tono' line if Rule 24 already in CLAUDE.md"
  echo "  - Compress 'Gates inmutables' to ID-only refs"
  echo "  - Remove 'Frontend' if not relevant to current task"
  exit 1
fi

echo "OK: $FILE = ~$TOKENS tokens ($WORDS words), cap=$CAP"
exit 0
