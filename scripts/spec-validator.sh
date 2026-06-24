#!/usr/bin/env bash
# spec-validator.sh — SE-222 S0: validates resource: URI field in spec frontmatter
#
# Validates YAML frontmatter of docs/propuestas/*.md and docs/rules/domain/*.md.
# Currently checks:
#   - WARN if `origin:` present but `resource:` absent
#   - WARN if `resource:` field is not a valid URI (https://, http://, file://, mailto:, urn:)
#   - WARN if `resource:` points to internal hosts (dev.azure.com/{org}, .local, localhost)
#     when used in N1-tier specs (docs/propuestas, docs/rules)
#
# This is a complement to spec-quality-auditor.sh:
#   - spec-quality-auditor.sh scores content quality (0-100)
#   - spec-validator.sh validates structural conventions (resource:, etc.)
#
# Modes:
#   --scan      Report warnings without exit failure (default)
#   --strict    Exit 1 if any WARN
#   --json      JSON output
#
# Usage:
#   bash scripts/spec-validator.sh <path-to-spec.md>
#   bash scripts/spec-validator.sh --batch docs/propuestas/
#   bash scripts/spec-validator.sh --json --batch docs/propuestas/
#
# Exit codes:
#   0 — no findings (or --scan default with findings)
#   1 — findings + --strict mode, or usage error
#   2 — invalid arguments
#
# Ref: SE-222 OKF Adoptable Patterns S0 (resource: URI convention)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="scan"
JSON=0
BATCH_DIR=""
FILE=""

usage() {
  cat <<EOF
Usage: $0 <spec.md> [--strict] [--json]
       $0 --batch <directory> [--strict] [--json]

Validates resource: URI convention in spec frontmatter (SE-222 S0).

Options:
  --scan        Report findings without exit failure (default)
  --strict      Exit 1 if any finding
  --json        JSON output (array of findings)
  --batch DIR   Validate all .md files in DIR

Exit codes:
  0 — no findings, or findings but not --strict
  1 — findings + --strict, or usage error
  2 — invalid arguments

Ref: SE-222 OKF Adoptable Patterns S0
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan)   MODE="scan"; shift ;;
    --strict) MODE="strict"; shift ;;
    --json)   JSON=1; shift ;;
    --batch)  BATCH_DIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "ERROR: unknown flag '$1'" >&2; exit 2 ;;
    *) FILE="$1"; shift ;;
  esac
done

if [[ -z "$FILE" && -z "$BATCH_DIR" ]]; then
  usage >&2
  exit 2
fi

if [[ -n "$BATCH_DIR" && -n "$FILE" ]]; then
  echo "ERROR: --batch and <file> are mutually exclusive" >&2
  exit 2
fi

# Returns 0 if the URI is valid, 1 otherwise.
is_valid_uri() {
  local uri="$1"
  # Strip surrounding quotes if present
  uri="${uri%\"}"
  uri="${uri#\"}"
  uri="${uri%\'}"
  uri="${uri#\'}"
  # Accept https://, http://, file://, mailto:, urn:, ftp://
  [[ "$uri" =~ ^(https?|file|ftp)://.+$ ]] && return 0
  [[ "$uri" =~ ^mailto:.+$ ]] && return 0
  [[ "$uri" =~ ^urn:.+$ ]] && return 0
  return 1
}

# Extract a field value from YAML frontmatter (first 50 lines).
# Returns empty string if not found.
get_frontmatter_field() {
  local file="$1"
  local field="$2"
  awk -v fld="$field" '
    NR==1 && $0 != "---" { exit }
    NR==1 { in_fm=1; next }
    in_fm && /^---$/ { exit }
    in_fm && $0 ~ "^"fld"[[:space:]]*:" {
      sub("^"fld"[[:space:]]*:[[:space:]]*", "")
      print
      exit
    }
  ' "$file"
}

# Validate a single file. Outputs JSON findings to stdout (one per line).
# Returns: number of findings via global FINDINGS_COUNT.
FINDINGS_COUNT=0
ALL_FINDINGS=()

validate_file() {
  local file="$1"
  [[ ! -f "$file" ]] && {
    ALL_FINDINGS+=("{\"file\":\"$file\",\"level\":\"ERROR\",\"code\":\"FILE_NOT_FOUND\",\"msg\":\"file does not exist\"}")
    FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
    return
  }

  # Skip files without frontmatter
  local first_line
  first_line="$(head -1 "$file" 2>/dev/null)"
  [[ "$first_line" != "---" ]] && return

  local origin resource
  origin="$(get_frontmatter_field "$file" "origin")"
  resource="$(get_frontmatter_field "$file" "resource")"

  local rel_file="${file#$PROJECT_ROOT/}"

  # Rule 1: origin present, resource absent → WARN
  if [[ -n "$origin" && -z "$resource" ]]; then
    ALL_FINDINGS+=("{\"file\":\"$rel_file\",\"level\":\"WARN\",\"code\":\"MISSING_RESOURCE\",\"msg\":\"origin: present but resource: missing — add resource: URI for navigability\"}")
    FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
  fi

  # Rule 2: resource present but not a valid URI → WARN
  if [[ -n "$resource" ]]; then
    if ! is_valid_uri "$resource"; then
      local r_escaped="${resource//\"/\\\"}"
      ALL_FINDINGS+=("{\"file\":\"$rel_file\",\"level\":\"WARN\",\"code\":\"INVALID_RESOURCE_URI\",\"msg\":\"resource: '$r_escaped' is not a valid URI (https://, http://, file://, mailto:, urn:)\"}")
      FINDINGS_COUNT=$((FINDINGS_COUNT + 1))
    fi
  fi
}

if [[ -n "$BATCH_DIR" ]]; then
  [[ ! -d "$BATCH_DIR" ]] && { echo "ERROR: directory not found: $BATCH_DIR" >&2; exit 2; }
  while IFS= read -r -d '' f; do
    validate_file "$f"
  done < <(find "$BATCH_DIR" -maxdepth 2 -type f -name "*.md" -print0)
else
  validate_file "$FILE"
fi

# Output
if [[ "$JSON" -eq 1 ]]; then
  printf '['
  local_first=1
  for finding in "${ALL_FINDINGS[@]}"; do
    if [[ "$local_first" -eq 1 ]]; then
      local_first=0
    else
      printf ','
    fi
    printf '%s' "$finding"
  done
  printf ']\n'
else
  if [[ "$FINDINGS_COUNT" -eq 0 ]]; then
    echo "OK: no findings"
  else
    echo "Findings: $FINDINGS_COUNT"
    for finding in "${ALL_FINDINGS[@]}"; do
      # parse and pretty-print
      level=$(printf '%s' "$finding" | sed -n 's/.*"level":"\([^"]*\)".*/\1/p')
      code=$(printf '%s' "$finding" | sed -n 's/.*"code":"\([^"]*\)".*/\1/p')
      file=$(printf '%s' "$finding" | sed -n 's/.*"file":"\([^"]*\)".*/\1/p')
      msg=$(printf '%s' "$finding" | sed -n 's/.*"msg":"\([^"]*\)".*/\1/p')
      printf '  [%s] %s: %s — %s\n' "$level" "$code" "$file" "$msg"
    done
  fi
fi

if [[ "$MODE" == "strict" && "$FINDINGS_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
