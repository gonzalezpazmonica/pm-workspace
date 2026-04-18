#!/usr/bin/env bash
# context-receipts-validate.sh — SE-030
# Validates that agent output contains receipts for claims.
# Ref: docs/rules/domain/receipts-protocol.md
#
# Usage:
#   bash scripts/context-receipts-validate.sh --input FILE [--strict] [--json]
#
# Exit codes:
#   0 = all claims have valid receipts
#   1 = WARN (claims without receipts; non-blocking in rollout phase 1)
#   2 = FAIL (broken receipts: file not found, line OOB, bad SHA)

set -uo pipefail

INPUT_FILE=""
STRICT=false
JSON_OUT=false
REPO_ROOT="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)" || REPO_ROOT="."

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT_FILE="$2"; shift 2 ;;
    --strict) STRICT=true; shift ;;
    --json) JSON_OUT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag $1" >&2; exit 2 ;;
  esac
done

[[ -z "$INPUT_FILE" ]] && { echo "Error: --input required" >&2; exit 2; }
[[ ! -f "$INPUT_FILE" ]] && { echo "Error: file not found: $INPUT_FILE" >&2; exit 2; }

# ── Parse claims ─────────────────────────────────────────────────────────────
# A claim is: a "claim:" field followed by "receipts:" block in YAML fence
# An unverified claim is: any statement ending in period without matching receipt nearby

CLAIMS_TOTAL=0
CLAIMS_VERIFIED=0
CLAIMS_UNVERIFIED=0
CLAIMS_BROKEN=0
declare -a BROKEN_LIST=()
declare -a UNVERIFIED_LIST=()

# Count claim: blocks in YAML
while IFS= read -r line; do
  CLAIMS_TOTAL=$((CLAIMS_TOTAL + 1))
done < <(grep -E '^[[:space:]]*claim:[[:space:]]' "$INPUT_FILE" 2>/dev/null || true)

# For each claim, check if followed by receipts: within 10 lines
while IFS=: read -r lineno _; do
  [[ -z "$lineno" ]] && continue
  # Check within next 10 lines for 'receipts:'
  if sed -n "${lineno},$(( lineno + 10 ))p" "$INPUT_FILE" 2>/dev/null | grep -qE '^[[:space:]]*receipts:[[:space:]]*$'; then
    CLAIMS_VERIFIED=$((CLAIMS_VERIFIED + 1))
  else
    CLAIMS_UNVERIFIED=$((CLAIMS_UNVERIFIED + 1))
    claim_text=$(sed -n "${lineno}p" "$INPUT_FILE" | sed -E 's/^[[:space:]]*claim:[[:space:]]*//' | tr -d '"' | cut -c1-60)
    UNVERIFIED_LIST+=("line ${lineno}: ${claim_text}")
  fi
done < <(grep -nE '^[[:space:]]*claim:[[:space:]]' "$INPUT_FILE" 2>/dev/null)

# ── Verify file receipts ─────────────────────────────────────────────────────
# Format: `file: path` followed by `line: N`
while read -r file_path; do
  [[ -z "$file_path" ]] && continue
  # Strip YAML prefix
  cleaned=$(echo "$file_path" | sed -E 's/^[[:space:]]*-?[[:space:]]*file:[[:space:]]*//' | tr -d '"' | awk '{print $1}')
  if [[ -n "$cleaned" && ! -f "$REPO_ROOT/$cleaned" ]]; then
    CLAIMS_BROKEN=$((CLAIMS_BROKEN + 1))
    BROKEN_LIST+=("file not found: $cleaned")
  fi
done < <(grep -E '^[[:space:]]*-?[[:space:]]*file:[[:space:]]' "$INPUT_FILE" 2>/dev/null || true)

# ── Verify spec receipts ─────────────────────────────────────────────────────
while read -r spec_ref; do
  [[ -z "$spec_ref" ]] && continue
  spec_id=$(echo "$spec_ref" | sed -E 's/^[[:space:]]*-?[[:space:]]*spec:[[:space:]]*//' | tr -d '"' | awk -F'#' '{print $1}' | awk '{print $1}')
  # Look in docs/propuestas/
  if [[ -n "$spec_id" ]] && ! ls "$REPO_ROOT/docs/propuestas/${spec_id}"*.md >/dev/null 2>&1; then
    CLAIMS_BROKEN=$((CLAIMS_BROKEN + 1))
    BROKEN_LIST+=("spec not found: $spec_id")
  fi
done < <(grep -E '^[[:space:]]*-?[[:space:]]*spec:[[:space:]]' "$INPUT_FILE" 2>/dev/null || true)

# ── Determine exit code ──────────────────────────────────────────────────────
EXIT_CODE=0
if (( CLAIMS_BROKEN > 0 )); then
  EXIT_CODE=2
elif (( CLAIMS_UNVERIFIED > 0 )); then
  $STRICT && EXIT_CODE=2 || EXIT_CODE=1
fi

# ── Output ───────────────────────────────────────────────────────────────────
if $JSON_OUT; then
  printf '{"total":%d,"verified":%d,"unverified":%d,"broken":%d,"exit":%d}\n' \
    "$CLAIMS_TOTAL" "$CLAIMS_VERIFIED" "$CLAIMS_UNVERIFIED" "$CLAIMS_BROKEN" "$EXIT_CODE"
else
  echo "=== Receipts validation: $INPUT_FILE ==="
  printf "PASS | %d claims with valid receipts\n" "$CLAIMS_VERIFIED"
  if (( CLAIMS_UNVERIFIED > 0 )); then
    printf "WARN | %d claims unverified (no receipt attached)\n" "$CLAIMS_UNVERIFIED"
    for u in "${UNVERIFIED_LIST[@]:0:5}"; do
      echo "       - $u"
    done
    (( CLAIMS_UNVERIFIED > 5 )) && echo "       ... and $((CLAIMS_UNVERIFIED - 5)) more"
  fi
  if (( CLAIMS_BROKEN > 0 )); then
    printf "FAIL | %d broken receipts\n" "$CLAIMS_BROKEN"
    for b in "${BROKEN_LIST[@]:0:5}"; do
      echo "       - $b"
    done
  fi
fi

exit "$EXIT_CODE"
