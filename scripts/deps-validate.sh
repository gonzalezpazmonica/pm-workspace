#!/usr/bin/env bash
# deps-validate.sh — SPEC-SE-020 Slice 1 schema validator for deps.yaml.
#
# Valida archivos `deps.yaml` de declaración de dependencias cross-project
# contra el schema definido en docs/rules/domain/portfolio-as-graph.md.
#
# Usage:
#   deps-validate.sh --file path/to/deps.yaml
#   deps-validate.sh --file path/to/deps.yaml --json
#   deps-validate.sh --file path/to/deps.yaml --strict
#
# Exit codes:
#   0 — schema valid
#   1 — schema errors (listed on stdout)
#   2 — usage error or file not found
#
# Ref: SPEC-SE-020, docs/rules/domain/portfolio-as-graph.md
# Safety: read-only, set -uo pipefail.

set -uo pipefail

FILE=""
JSON=0
STRICT=0

usage() {
  cat <<EOF
Usage:
  $0 --file PATH         Validate a deps.yaml against schema
  $0 --file PATH --json  Output JSON verdict
  $0 --file PATH --strict  WARNs are treated as errors

Required top-level keys: project, tenant, dependencies.
Enums: type ∈ {blocks,feeds,shared-resource,shared-platform}
       status ∈ {on-track,at-risk,blocked,delivered}

Ref: docs/rules/domain/portfolio-as-graph.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --strict) STRICT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$FILE" ]] && { echo "ERROR: --file required" >&2; exit 2; }
[[ ! -f "$FILE" ]] && { echo "ERROR: file not found: $FILE" >&2; exit 2; }

ERRORS=()
WARNINGS=()

add_err() { ERRORS+=("$1"); }
add_warn() { WARNINGS+=("$1"); }

# ── Top-level required keys ─────────────────────────────────────────────────

has_key() {
  # checks whether a top-level key is present (accounting for indent 0).
  grep -qE "^$1:" "$FILE"
}

has_key "project" || add_err "missing required key 'project'"
has_key "tenant"  || add_err "missing required key 'tenant'"
has_key "dependencies" || add_err "missing required key 'dependencies'"

# Extract project name for output.
PROJECT=$(grep -E '^project:' "$FILE" | head -1 | sed -E 's/^project:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/' | tr -d ' ')
[[ -z "$PROJECT" ]] && PROJECT="(unknown)"

# Validate project is non-empty and slug-ish (no spaces, reasonable chars).
if [[ -n "$PROJECT" && "$PROJECT" != "(unknown)" ]]; then
  if [[ "$PROJECT" =~ [[:space:]] ]]; then
    add_err "'project' must not contain spaces: got '$PROJECT'"
  fi
fi

# Tenant check (kebab-slug).
TENANT=$(grep -E '^tenant:' "$FILE" | head -1 | sed -E 's/^tenant:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/' | tr -d ' ')
if [[ -n "$TENANT" ]]; then
  if ! [[ "$TENANT" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
    add_warn "'tenant' should be kebab-slug (lowercase, digits, dashes): got '$TENANT'"
  fi
fi

# ── Enum validation: type ───────────────────────────────────────────────────

VALID_TYPES="blocks feeds shared-resource shared-platform"
# Collect all "type:" values under dependencies.
TYPES=$(grep -E '^\s+type:' "$FILE" | sed -E 's/^\s+type:\s*"?([^"]*)"?\s*$/\1/' | tr -d ' ')
while IFS= read -r t; do
  [[ -z "$t" ]] && continue
  if ! echo " $VALID_TYPES " | grep -q " $t "; then
    add_err "invalid 'type' value: '$t' (allowed: $VALID_TYPES)"
  fi
done <<< "$TYPES"

# ── Enum validation: status ─────────────────────────────────────────────────

VALID_STATUS="on-track at-risk blocked delivered"
STATUSES=$(grep -E '^\s+status:' "$FILE" | sed -E 's/^\s+status:\s*"?([^"]*)"?\s*$/\1/' | tr -d ' ')
while IFS= read -r s; do
  [[ -z "$s" ]] && continue
  if ! echo " $VALID_STATUS " | grep -q " $s "; then
    add_err "invalid 'status' value: '$s' (allowed: $VALID_STATUS)"
  fi
done <<< "$STATUSES"

# ── Date format validation: needed_by ───────────────────────────────────────

DATES=$(grep -E '^\s+needed_by:' "$FILE" | sed -E 's/^\s+needed_by:\s*"?([^"]*)"?\s*$/\1/' | tr -d ' ')
while IFS= read -r d; do
  [[ -z "$d" ]] && continue
  if ! [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    add_err "invalid 'needed_by' date format: '$d' (expected YYYY-MM-DD)"
  fi
done <<< "$DATES"

# ── Contact format validation ───────────────────────────────────────────────

CONTACTS=$(grep -E '^\s+contact:' "$FILE" | sed -E 's/^\s+contact:\s*"?([^"]*)"?\s*$/\1/' | tr -d ' ')
while IFS= read -r c; do
  [[ -z "$c" ]] && continue
  if ! [[ "$c" =~ ^@[a-zA-Z0-9_-]+$ ]]; then
    add_warn "'contact' should be @handle: got '$c'"
  fi
done <<< "$CONTACTS"

# ── Shared resources validation ─────────────────────────────────────────────

# Counts.
UPSTREAM_COUNT=$(awk '/^\s+upstream:/{f=1;next} /^\s+[a-zA-Z_]+:/&&!/^\s+-/{f=0} f&&/^\s+-\s+project:/{c++} END{print c+0}' "$FILE")
DOWNSTREAM_COUNT=$(awk '/^\s+downstream:/{f=1;next} /^\s+[a-zA-Z_]+:/&&!/^\s+-/{f=0} f&&/^\s+-\s+project:/{c++} END{print c+0}' "$FILE")
SHARED_COUNT=$(grep -cE '^\s+-\s+person:' "$FILE" || echo 0)

# ── Emit verdict ────────────────────────────────────────────────────────────

VALID=1
if [[ "${#ERRORS[@]}" -gt 0 ]]; then
  VALID=0
fi
if [[ "$STRICT" -eq 1 && "${#WARNINGS[@]}" -gt 0 ]]; then
  VALID=0
fi

if [[ "$JSON" -eq 1 ]]; then
  # Build JSON arrays manually.
  err_json=""
  for e in "${ERRORS[@]}"; do
    e_esc=$(echo "$e" | sed 's/"/\\"/g')
    err_json+="\"$e_esc\","
  done
  err_json="${err_json%,}"
  warn_json=""
  for w in "${WARNINGS[@]}"; do
    w_esc=$(echo "$w" | sed 's/"/\\"/g')
    warn_json+="\"$w_esc\","
  done
  warn_json="${warn_json%,}"
  valid_bool=$([[ "$VALID" -eq 1 ]] && echo "true" || echo "false")
  cat <<JSON
{"valid":$valid_bool,"project":"$PROJECT","upstream":$UPSTREAM_COUNT,"downstream":$DOWNSTREAM_COUNT,"shared_resources":$SHARED_COUNT,"errors":[$err_json],"warnings":[$warn_json]}
JSON
else
  if [[ "$VALID" -eq 1 ]]; then
    echo "VALID: deps.yaml schema OK for project '$PROJECT'"
    echo "  - ${UPSTREAM_COUNT} upstream · ${DOWNSTREAM_COUNT} downstream · ${SHARED_COUNT} shared_resource"
    if [[ "${#WARNINGS[@]}" -gt 0 ]]; then
      echo "  Warnings:"
      for w in "${WARNINGS[@]}"; do echo "    - $w"; done
    fi
  else
    echo "INVALID: deps.yaml schema errors in '$FILE' (project='$PROJECT')"
    for e in "${ERRORS[@]}"; do echo "  ERR: $e"; done
    if [[ "${#WARNINGS[@]}" -gt 0 ]]; then
      for w in "${WARNINGS[@]}"; do echo "  WARN: $w"; done
    fi
  fi
fi

[[ "$VALID" -eq 0 ]] && exit 1
exit 0
