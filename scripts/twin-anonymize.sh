#!/usr/bin/env bash
# twin-anonymize.sh — Genera vista N1 de un twin sin datos de organización (SPEC-169 AC-6)
# Usage: bash scripts/twin-anonymize.sh {slug} [--out docs/case-studies/{slug-anon}.twin.md]
# Exit: 0 OK | 2 ERROR
# Applies: zero-project-leakage rules (removes org name, handles, real paths)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${TWIN_ROOT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

SLUG="${1:-}"
[[ -z "$SLUG" ]] && { echo "Usage: twin-anonymize.sh {slug} [--out <path>]" >&2; exit 2; }

TWIN_FILE="${ROOT_DIR}/projects/${SLUG}/twin.md"
[[ ! -f "$TWIN_FILE" ]] && { echo "ERROR: twin not found: ${TWIN_FILE}" >&2; exit 2; }

# Default output path
SLUG_ANON=$(echo "$SLUG" | sed 's/[aeiouAEIOU]//g' | cut -c1-8)-anon
OUT_DIR="${ROOT_DIR}/docs/case-studies"
OUT_FILE="${OUT_DIR}/${SLUG_ANON}.twin.md"

# Parse --out override
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT_FILE="${2:-$OUT_FILE}"; shift 2 ;;
    *) shift ;;
  esac
done

CONTENT=$(cat "$TWIN_FILE")

# ── Anonymization transformations ────────────────────────────────────────────
# 1. Replace twin_id with anon slug
CONTENT=$(echo "$CONTENT" | sed "s|twin_id: \"${SLUG}\"|twin_id: \"${SLUG_ANON}\"|g")

# 1b. Strip absolute ROOT_DIR prefix from all paths
CONTENT=$(echo "$CONTENT" | sed "s|${ROOT_DIR}/||g")

# 2. Replace projects/{slug}/ paths with generic evidence ref
CONTENT=$(echo "$CONTENT" | sed "s|projects/${SLUG}/|case-study/|g")

# 3. Remove any handle-like patterns (@word)
CONTENT=$(echo "$CONTENT" | sed -E 's/@[a-z][a-z0-9_-]+/@role/g')

# 4. Replace org-specific project names loaded from local gitignored list
# Add project names (one per line) to: .claude/rules/twin-anon-projects.local.txt
LOCAL_PROJECTS_FILE="${ROOT_DIR}/.claude/rules/twin-anon-projects.local.txt"
if [[ -f "$LOCAL_PROJECTS_FILE" ]]; then
  while IFS= read -r proj || [[ -n "$proj" ]]; do
    [[ -z "$proj" || "$proj" == \#* ]] && continue
    CONTENT=$(echo "$CONTENT" | sed -E "s|${proj}|[PROJECT]|gI")
  done < "$LOCAL_PROJECTS_FILE"
fi

# 5. Redact free-text blocker descriptions (keep only type hint)
# Replace specific-looking blocker text (>20 chars) with placeholder
CONTENT=$(echo "$CONTENT" | sed -E 's/(value: "[^"]{20,}")/value: "[blocker details redacted]"/g')

# 6. Strip last_refresh timestamp precision to month
CONTENT=$(echo "$CONTENT" | sed -E 's/(last_refresh: ")[0-9]{4}-([0-9]{2})-[0-9]{2}T[^"]*/\12026-\2-XX/g')

mkdir -p "$OUT_DIR"
printf '%s\n' "$CONTENT" > "$OUT_FILE"

echo "OK: anonymized twin written to ${OUT_FILE}"
exit 0
