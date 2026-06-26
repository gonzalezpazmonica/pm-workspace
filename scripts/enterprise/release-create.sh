#!/usr/bin/env bash
set -uo pipefail
# release-create.sh — SE-014 Release Orchestration
#
# Crea un nuevo release siguiendo Release-as-Code.
#
# Usage:
#   bash scripts/enterprise/release-create.sh --version V --tenant SLUG [--compliance-profile basic|eu-ai-act|dora]
#
# Output:
#   Crea tenants/{slug}/releases/{version}/release.yaml
#
# Exit codes: 0 ok | 1 error | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-014-release-orchestration.md

VERSION=""
TENANT=""
COMPLIANCE_PROFILE="basic"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)          VERSION="$2";           shift 2 ;;
    --tenant)           TENANT="$2";            shift 2 ;;
    --compliance-profile) COMPLIANCE_PROFILE="$2"; shift 2 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$VERSION" || -z "$TENANT" ]]; then
  echo "ERROR: --version and --tenant are required" >&2
  exit 2
fi

case "$COMPLIANCE_PROFILE" in
  basic|eu-ai-act|dora) ;;
  *) echo "ERROR: --compliance-profile must be basic|eu-ai-act|dora" >&2; exit 2 ;;
esac

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
RELEASE_DIR="${REPO_ROOT}/tenants/${TENANT}/releases/${VERSION}"

if [[ -d "$RELEASE_DIR" ]]; then
  echo "ERROR: Release '${VERSION}' already exists for tenant '${TENANT}'" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"

CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build checklist according to compliance profile
build_checklist() {
  local profile="$1"
  case "$profile" in
    basic)
      cat <<'EOF'
checklist:
  - id: tests_passing
    description: All automated tests pass
    required: true
    passed: false
  - id: changelog_updated
    description: CHANGELOG updated with release notes
    required: true
    passed: false
  - id: human_approval
    description: At least one human approver sign-off
    required: true
    passed: false
  - id: audit_trail_complete
    description: All actions logged in audit trail
    required: true
    passed: false
EOF
      ;;
    eu-ai-act)
      cat <<'EOF'
checklist:
  - id: tests_passing
    description: All automated tests pass
    required: true
    passed: false
  - id: model_cards_present
    description: AI model cards documented
    required: true
    passed: false
  - id: bias_evaluation
    description: Bias evaluation completed
    required: true
    passed: false
  - id: human_oversight_gate
    description: Human oversight mechanism verified
    required: true
    passed: false
  - id: audit_trail_complete
    description: All actions logged in audit trail
    required: true
    passed: false
  - id: human_approval
    description: At least one human approver sign-off
    required: true
    passed: false
  - id: dpia_reviewed
    description: Data protection impact assessment reviewed
    required: true
    passed: false
EOF
      ;;
    dora)
      cat <<'EOF'
checklist:
  - id: tests_passing
    description: All automated tests pass
    required: true
    passed: false
  - id: change_window_approved
    description: Change window approved by CAB
    required: true
    passed: false
  - id: rollback_playbook_tested
    description: Rollback playbook tested
    required: true
    passed: false
  - id: incident_response_ready
    description: Incident response team on standby
    required: true
    passed: false
  - id: audit_trail_complete
    description: All actions logged in audit trail
    required: true
    passed: false
  - id: human_approval
    description: Release manager sign-off
    required: true
    passed: false
  - id: security_officer_approval
    description: Security officer sign-off
    required: true
    passed: false
  - id: model_cards_present
    description: Documentation artifacts present
    required: true
    passed: false
EOF
      ;;
  esac
}

cat > "${RELEASE_DIR}/release.yaml" <<EOF
version: "${VERSION}"
tenant: "${TENANT}"
created_at: "${CREATED_AT}"
status: draft
compliance_profile: "${COMPLIANCE_PROFILE}"
$(build_checklist "$COMPLIANCE_PROFILE")
EOF

echo "Release created: ${RELEASE_DIR}/release.yaml"
echo "  version:            ${VERSION}"
echo "  tenant:             ${TENANT}"
echo "  compliance_profile: ${COMPLIANCE_PROFILE}"
echo "  status:             draft"
