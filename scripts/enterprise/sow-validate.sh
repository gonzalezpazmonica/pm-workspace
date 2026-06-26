#!/usr/bin/env bash
set -uo pipefail
# sow-validate.sh — SE-017 Project Definition (SOW-as-Code)
#
# Valida que un SOW tiene todas las secciones requeridas.
#
# Usage:
#   bash scripts/enterprise/sow-validate.sh --project SLUG --tenant SLUG
#   bash scripts/enterprise/sow-validate.sh --file PATH/TO/sow.md
#
# Output JSON: {complete: bool, missing_sections: [...], word_count: N}
#
# Exit codes: 0 valid | 1 invalid (missing sections) | 2 usage error | 3 file not found
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-017-project-definition.md

PROJECT=""
TENANT=""
SOW_FILE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --tenant)  TENANT="$2";  shift 2 ;;
    --file)    SOW_FILE_ARG="$2"; shift 2 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

if [[ -n "$SOW_FILE_ARG" ]]; then
  SOW_FILE="$SOW_FILE_ARG"
elif [[ -n "$PROJECT" && -n "$TENANT" ]]; then
  SOW_FILE="${REPO_ROOT}/tenants/${TENANT}/projects/${PROJECT}/sow.md"
else
  echo "ERROR: provide --file PATH or both --project and --tenant" >&2
  exit 2
fi

if [[ ! -f "$SOW_FILE" ]]; then
  echo "ERROR: SOW file not found: ${SOW_FILE}" >&2
  exit 3
fi

# Required sections (case-insensitive check in markdown headings)
required_sections=(
  "objective"
  "scope"
  "deliverables"
  "timeline"
  "acceptance"
  "exclusions"
)

missing_sections=()
content="$(cat "$SOW_FILE")"

for section in "${required_sections[@]}"; do
  # Check for ## heading containing the section name (case-insensitive)
  if ! echo "$content" | grep -qi "^## .*${section}"; then
    missing_sections+=("$section")
  fi
done

# Word count (excluding frontmatter)
word_count=$(echo "$content" | sed '/^---$/,/^---$/d' | wc -w)

# Build JSON
missing_json="["
first=true
for s in "${missing_sections[@]}"; do
  if [[ "$first" == false ]]; then
    missing_json="${missing_json},"
  fi
  missing_json="${missing_json}\"${s}\""
  first=false
done
missing_json="${missing_json}]"

if [[ "${#missing_sections[@]}" -eq 0 ]]; then
  complete="true"
  exit_code=0
else
  complete="false"
  exit_code=1
fi

printf '{"complete":%s,"missing_sections":%s,"word_count":%d}\n' \
  "$complete" "$missing_json" "$word_count"

exit "$exit_code"
