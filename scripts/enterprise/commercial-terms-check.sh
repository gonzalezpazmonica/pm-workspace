#!/usr/bin/env bash
# commercial-terms-check.sh — SPEC-SE-008 License and Commercial Terms Verifier
set -uo pipefail
#
# Verifica que la instalacion cumple los terminos de uso de Savia Enterprise.
# Checks:
#   1. MIT license present in main components
#   2. Attribution documented
#   3. No incompatible licenses (GPL, AGPL, SSPL, BSL)
#   4. Contributor Covenant present
#   5. Enterprise licensing policy exists
#
# Output JSON: {compliant, license_type, assessed_at, critical_issues, issues, checks}
#
# Reference: SPEC-SE-008

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

usage() {
  cat <<'EOF'
commercial-terms-check.sh — SPEC-SE-008 License Verifier

Usage:
  commercial-terms-check.sh [--output-file PATH] [--strict]
  commercial-terms-check.sh --help

Output: JSON {compliant: bool, license_type: "MIT", issues: [...], checks: [...]}
EOF
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 2; }

OUTPUT_FILE=""
STRICT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-file) OUTPUT_FILE="$2"; shift 2 ;;
    --strict)      STRICT=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

ASSESSED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
CHECKS_JSON=""
ISSUES_JSON=""
COMPLIANT=1
CRITICAL_ISSUES=0

add_check() {
  local rule="$1" passed="$2" detail="$3" critical="${4:-false}"
  local sep=""
  [[ -n "$CHECKS_JSON" ]] && sep=","
  detail="${detail//\"/\\\"}"
  CHECKS_JSON="${CHECKS_JSON}${sep}{\"rule\":\"${rule}\",\"passed\":${passed},\"detail\":\"${detail}\",\"critical\":${critical}}"
  if [[ "$passed" == "false" ]]; then
    COMPLIANT=0
    local isep=""
    [[ -n "$ISSUES_JSON" ]] && isep=","
    ISSUES_JSON="${ISSUES_JSON}${isep}\"${rule}: ${detail}\""
    [[ "$critical" == "true" ]] && CRITICAL_ISSUES=$(( CRITICAL_ISSUES + 1 ))
  fi
}

# Check 1: MIT license
MIT_FILES=""
for loc in "${ROOT_DIR}/LICENSE" "${ROOT_DIR}/LICENSE.md" "${ROOT_DIR}/LICENSE-ENTERPRISE.md"; do
  if [[ -f "$loc" ]]; then
    if grep -qi "MIT License\|Permission is hereby granted" "$loc" 2>/dev/null; then
      MIT_FILES="${MIT_FILES} $(basename "$loc")"
    fi
  fi
done

if [[ -n "$MIT_FILES" ]]; then
  add_check "mit_license_present" "true" "MIT license found: ${MIT_FILES}" "true"
else
  add_check "mit_license_present" "false" "No MIT license file found. Expected: LICENSE, LICENSE.md, or LICENSE-ENTERPRISE.md" "true"
fi

# Check 2: Attribution documented
ATTR_FOUND=""
for f in \
  "${ROOT_DIR}/docs/rules/domain/enterprise-licensing-policy.md" \
  "${ROOT_DIR}/LICENSE-ENTERPRISE.md" \
  "${ROOT_DIR}/TRADEMARK.md"; do
  [[ -f "$f" ]] && ATTR_FOUND="${ATTR_FOUND} $(basename "$f")"
done

if [[ -n "$ATTR_FOUND" ]]; then
  add_check "attribution_documented" "true" "Attribution docs: ${ATTR_FOUND}" "false"
else
  add_check "attribution_documented" "false" "No attribution/trademark docs found" "false"
fi

# Check 3: No incompatible licenses
INCOMPAT=""
while IFS= read -r f; do
  if grep -qE "GPL-[23]\.0|AGPL|SSPL|Business Source" "$f" 2>/dev/null; then
    INCOMPAT="${INCOMPAT} $(basename "$f")"
  fi
done < <(find "${ROOT_DIR}/scripts/enterprise" -name "*.sh" 2>/dev/null)

if [[ -z "$INCOMPAT" ]]; then
  add_check "no_incompatible_licenses" "true" "No GPL/AGPL/SSPL detected in enterprise scripts" "true"
else
  add_check "no_incompatible_licenses" "false" "Incompatible license text in: ${INCOMPAT}" "true"
fi

# Check 4: Contributor Covenant
COC_FILE="${ROOT_DIR}/CODE_OF_CONDUCT.md"
if [[ -f "$COC_FILE" ]] && grep -qi "Contributor Covenant\|Code of Conduct" "$COC_FILE" 2>/dev/null; then
  add_check "contributor_covenant" "true" "CODE_OF_CONDUCT.md with Contributor Covenant found" "false"
else
  add_check "contributor_covenant" "false" "CODE_OF_CONDUCT.md not found or missing Contributor Covenant" "false"
fi

# Check 5: Licensing policy
POLICY="${ROOT_DIR}/docs/rules/domain/enterprise-licensing-policy.md"
if [[ -f "$POLICY" ]]; then
  add_check "licensing_policy_exists" "true" "enterprise-licensing-policy.md present" "false"
else
  add_check "licensing_policy_exists" "false" "enterprise-licensing-policy.md not found" "false"
fi

COMPLIANT_BOOL="true"
[[ "$COMPLIANT" -eq 0 ]] && COMPLIANT_BOOL="false"

RESULT="{\"compliant\":${COMPLIANT_BOOL},\"license_type\":\"MIT\",\"assessed_at\":\"${ASSESSED_AT}\",\"critical_issues\":${CRITICAL_ISSUES},\"issues\":[${ISSUES_JSON}],\"checks\":[${CHECKS_JSON}]}"

if [[ -n "$OUTPUT_FILE" ]]; then
  echo "$RESULT" > "$OUTPUT_FILE"
  echo "Written to ${OUTPUT_FILE}" >&2
else
  echo "$RESULT"
fi

if [[ "$CRITICAL_ISSUES" -gt 0 ]]; then exit 1; fi
if [[ "$STRICT" -eq 1 ]] && [[ "$COMPLIANT" -eq 0 ]]; then exit 1; fi
exit 0
