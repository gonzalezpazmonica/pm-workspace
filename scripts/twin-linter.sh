#!/usr/bin/env bash
# twin-linter.sh — Valida twin.md contra schema SPEC-169
# Spec: SPEC-169 · AC-1, AC-7
# Usage: bash scripts/twin-linter.sh <path/to/twin.md>
# Exit: 0 OK | 1 STALE | 2 INVALID | 3 FORBIDDEN_FIELD
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TWIN_FILE="${1:-}"
FORBIDDEN_FILE="${SCRIPT_DIR}/twin-forbidden-fields.txt"

[[ -z "$TWIN_FILE" ]] && { echo "Usage: twin-linter.sh <twin.md>" >&2; exit 2; }
[[ ! -f "$TWIN_FILE" ]] && { echo "ERROR: file not found: $TWIN_FILE" >&2; exit 2; }

frontmatter() { awk '/^---$/{c++;if(c==2)exit;next} c==1{print}' "$TWIN_FILE"; }
fm_field()    { frontmatter | grep -E "^${1}:" | head -1 | sed -E "s/^${1}:[[:space:]]*//" | tr -d '"'; }
has_section() { grep -qE "^## ${1}" "$TWIN_FILE"; }

ERRORS=0

# 1. Required frontmatter fields
for field in twin_id spec_version last_refresh stale_after_days token_budget health; do
  [[ -z "$(fm_field "$field")" ]] && { echo "INVALID: missing '$field'" >&2; ERRORS=$((ERRORS+1)); }
done

# 2. Predictions block
for pred in sprint_slip next_blocker scope_drift aggregate_health; do
  frontmatter | grep -qE "^[[:space:]]+${pred}:" || { echo "INVALID: missing prediction '${pred}'" >&2; ERRORS=$((ERRORS+1)); }
done

# confidence in [0,1]
while IFS= read -r line; do
  echo "$line" | grep -qE "confidence:[[:space:]]*[0-9]" || continue
  conf=$(echo "$line" | grep -oE "[0-9]+\.[0-9]+|[0-9]+" | head -1)
  awk -v c="$conf" 'BEGIN{exit(c>=0&&c<=1)?0:1}' || { echo "INVALID: confidence out of range: $conf" >&2; ERRORS=$((ERRORS+1)); }
done < <(frontmatter)

# evidence_ref non-null
while IFS= read -r line; do
  echo "$line" | grep -qE "evidence_ref:[[:space:]]*$" && { echo "INVALID: empty evidence_ref" >&2; ERRORS=$((ERRORS+1)); }
done < <(frontmatter)

# 3. Required sections
for section in "Estado" "Reglas" "Predicciones"; do
  has_section "$section" || { echo "INVALID: missing section '## ${section}'" >&2; ERRORS=$((ERRORS+1)); }
done

[[ "$ERRORS" -gt 0 ]] && exit 2

# 4. Forbidden fields (AC-7) — read patterns from config file
BODY=$(awk '/^---$/{c++; if(c==2){found=1;next}} found{print}' "$TWIN_FILE")
FORBIDDEN_FOUND=0
if [[ -f "$FORBIDDEN_FILE" ]]; then
  while IFS= read -r pat; do
    [[ -z "$pat" || "$pat" == \#* ]] && continue
    echo "$BODY" | grep -qiE "$pat" && { echo "FORBIDDEN: pattern '${pat}' in body" >&2; FORBIDDEN_FOUND=$((FORBIDDEN_FOUND+1)); }
  done < "$FORBIDDEN_FILE"
fi
[[ "$FORBIDDEN_FOUND" -gt 0 ]] && exit 3

# 5. Decay check (bash only, no Python)
last_refresh=$(fm_field "last_refresh")
stale_days=$(fm_field "stale_after_days")
if [[ -n "$last_refresh" && -n "$stale_days" ]]; then
  ref_epoch=$(date -d "${last_refresh}" +%s 2>/dev/null || true)
  now_epoch=$(date +%s)
  if [[ -n "$ref_epoch" ]]; then
    delta_days=$(( (now_epoch - ref_epoch) / 86400 ))
    if [[ "$delta_days" -gt "$stale_days" ]]; then
      echo "STALE: last_refresh=${last_refresh} exceeds stale_after_days=${stale_days}" >&2
      exit 1
    fi
  fi
fi

echo "OK: ${TWIN_FILE}"
exit 0
