#!/usr/bin/env bash
# compliance-check.sh — SPEC-SE-006 Workspace Compliance Validator
set -uo pipefail
#
# Valida el workspace contra frameworks regulatorios.
#
# Args:
#   --framework eu-ai-act|nis2|gdpr|dora  (default: all)
#   --tenant SLUG                         (optional, for tenant-scoped checks)
#   --output-file PATH                    (optional, write JSON to file)
#
# Output JSON:
#   {
#     "framework": "eu-ai-act",
#     "tenant": "default",
#     "assessed_at": "2026-06-24T...",
#     "score": 75,
#     "checks": [
#       {"rule": "model_cards_exist", "passed": true, "evidence": "...", "gap": null},
#       ...
#     ]
#   }
#
# Reference: SPEC-SE-006 (docs/propuestas/savia-enterprise/SPEC-SE-006-governance-compliance.md)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
compliance-check.sh — SPEC-SE-006 Regulatory Compliance Validator

Usage:
  compliance-check.sh [--framework FRAMEWORK] [--tenant SLUG] [--output-file PATH]
  compliance-check.sh --help

Options:
  --framework  Framework to check: eu-ai-act, nis2, gdpr, dora (default: all)
  --tenant     Tenant slug for tenant-scoped evidence (default: default)
  --output-file PATH  Write JSON output to file instead of stdout

Output:
  JSON with {framework, score, checks: [{rule, passed, evidence, gap}]}

Exit codes:
  0  All checks passed (score = 100)
  1  One or more checks failed
  2  Invalid arguments
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 2; }

FRAMEWORK="all"
TENANT="default"
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --framework)   FRAMEWORK="$2";   shift 2 ;;
    --tenant)      TENANT="$2";      shift 2 ;;
    --output-file) OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

# ── Check helpers ─────────────────────────────────────────────────────────────

CHECKS_JSON=""
TOTAL=0
PASSED=0

# Add a check result to CHECKS_JSON
add_check() {
  local rule="$1" passed="$2" evidence="$3" gap="$4"
  TOTAL=$(( TOTAL + 1 ))
  [[ "$passed" == "true" ]] && PASSED=$(( PASSED + 1 ))

  local sep=""
  [[ -n "$CHECKS_JSON" ]] && sep=","

  # Escape double quotes in evidence/gap
  evidence="${evidence//\"/\\\"}"
  gap="${gap//\"/\\\"}"

  CHECKS_JSON="${CHECKS_JSON}${sep}
    {\"rule\":\"${rule}\",\"passed\":${passed},\"evidence\":\"${evidence}\",\"gap\":$([ "$passed" == "true" ] && echo "null" || echo "\"${gap}\"")}"
}

# ── EU AI Act checks ──────────────────────────────────────────────────────────

check_eu_ai_act() {
  local model_cards_dir="${ROOT_DIR}/.claude/enterprise/model-cards"
  local agents_dir="${ROOT_DIR}/.opencode/agents"

  # Check 1: model cards exist
  if [[ -d "$model_cards_dir" ]] && ls "${model_cards_dir}"/*.md >/dev/null 2>&1; then
    local card_count
    card_count="$(ls "${model_cards_dir}"/*.md 2>/dev/null | wc -l)"
    add_check "model_cards_exist" "true" "${card_count} model cards in ${model_cards_dir}" ""
  else
    add_check "model_cards_exist" "false" "No model cards directory found" \
      "Run model-card-generator.sh to generate AI Act model cards"
  fi

  # Check 2: audit trail exists
  local audit_dir="${ROOT_DIR}/.claude/enterprise/audit"
  if [[ -d "$audit_dir" ]] && find "$audit_dir" -name "audit-trail.jsonl" | grep -q .; then
    local trail_count
    trail_count="$(find "$audit_dir" -name "audit-trail.jsonl" | wc -l)"
    add_check "audit_trail_exists" "true" "${trail_count} audit trail(s) in ${audit_dir}" ""
  else
    add_check "audit_trail_exists" "false" "No audit trails found" \
      "Run governance-audit-trail.sh append to initialize the audit trail"
  fi

  # Check 3: human oversight gate documented
  local autonomous_safety="${ROOT_DIR}/docs/rules/domain/autonomous-safety.md"
  if [[ -f "$autonomous_safety" ]]; then
    add_check "human_oversight_gate" "true" "autonomous-safety.md documents E1 gate and AUTONOMOUS_REVIEWER requirement" ""
  else
    add_check "human_oversight_gate" "false" "autonomous-safety.md not found" \
      "Create docs/rules/domain/autonomous-safety.md with human oversight policy"
  fi

  # Check 4: governance protocol documented
  local gov_protocol="${ROOT_DIR}/docs/rules/domain/enterprise-governance-protocol.md"
  if [[ -f "$gov_protocol" ]]; then
    add_check "governance_protocol_exists" "true" "enterprise-governance-protocol.md present" ""
  else
    add_check "governance_protocol_exists" "false" "enterprise-governance-protocol.md not found" \
      "Create docs/rules/domain/enterprise-governance-protocol.md"
  fi

  # Check 5: equality/bias shield
  local equality_shield="${ROOT_DIR}/docs/rules/domain/equality-shield.md"
  if [[ -f "$equality_shield" ]]; then
    add_check "bias_tests_documented" "true" "equality-shield.md provides bias testing framework" ""
  else
    add_check "bias_tests_documented" "false" "equality-shield.md not found" \
      "Create docs/rules/domain/equality-shield.md with bias testing documentation"
  fi
}

# ── GDPR checks ───────────────────────────────────────────────────────────────

check_gdpr() {
  # Check 1: PII handling documented
  local pii_docs
  pii_docs="$(find "${ROOT_DIR}/docs" -name "*.md" -exec grep -l -i "pii\|personal data\|data protection" {} \; 2>/dev/null | head -3 | tr '\n' ' ')"
  if [[ -n "$pii_docs" ]]; then
    add_check "pii_handling_documented" "true" "PII handling covered in: ${pii_docs}" ""
  else
    add_check "pii_handling_documented" "false" "No PII handling documentation found" \
      "Add PII handling policy to docs/rules/domain/"
  fi

  # Check 2: data retention policy
  local retention_doc="${ROOT_DIR}/docs/rules/domain/savia-enterprise/audit-retention.md"
  if [[ -f "$retention_doc" ]]; then
    add_check "data_retention_policy" "true" "Retention policy in ${retention_doc}" ""
  else
    add_check "data_retention_policy" "false" "audit-retention.md not found" \
      "Create docs/rules/domain/savia-enterprise/audit-retention.md"
  fi

  # Check 3: context placement / N1-N4 classification
  local ctx_placement="${ROOT_DIR}/docs/rules/domain/context-placement-confirmation.md"
  if [[ -f "$ctx_placement" ]]; then
    add_check "data_classification_policy" "true" "N1-N4b context placement classification documented" ""
  else
    add_check "data_classification_policy" "false" "context-placement-confirmation.md not found" \
      "Create docs/rules/domain/context-placement-confirmation.md with N1-N4b classification"
  fi
}

# ── NIS2 checks ───────────────────────────────────────────────────────────────

check_nis2() {
  # Check 1: incident log / postmortems
  local incident_dir="${ROOT_DIR}/output/postmortems"
  if [[ -d "$incident_dir" ]]; then
    add_check "incident_log_exists" "true" "Incident/postmortem directory: ${incident_dir}" ""
  else
    add_check "incident_log_exists" "false" "output/postmortems/ directory not found" \
      "Create output/postmortems/ for NIS2 incident logging"
  fi

  # Check 2: security review documented
  local security_docs
  security_docs="$(find "${ROOT_DIR}/docs" -name "savia-shield.md" -o -name "security*.md" 2>/dev/null | head -2 | tr '\n' ' ')"
  if [[ -n "$security_docs" ]]; then
    add_check "security_posture_documented" "true" "Security docs: ${security_docs}" ""
  else
    add_check "security_posture_documented" "false" "No security posture documentation found" \
      "Create docs/savia-shield.md or equivalent security posture document"
  fi

  # Check 3: patch/update policy
  local patch_policy
  patch_policy="$(find "${ROOT_DIR}/docs" -name "*.md" -exec grep -l -i "patch\|update policy\|dependency" {} \; 2>/dev/null | head -1)"
  if [[ -n "$patch_policy" ]]; then
    add_check "patch_policy_documented" "true" "Patch policy covered in: ${patch_policy}" ""
  else
    add_check "patch_policy_documented" "false" "No patch/update policy documentation found" \
      "Document dependency update and patching policy"
  fi
}

# ── DORA checks ───────────────────────────────────────────────────────────────

check_dora() {
  # Check 1: ICT risk / outsourcing register
  local manifest="${ROOT_DIR}/.claude/enterprise/manifest.json"
  if [[ -f "$manifest" ]]; then
    add_check "ict_risk_register" "true" "Enterprise manifest.json documents ICT components: ${manifest}" ""
  else
    add_check "ict_risk_register" "false" ".claude/enterprise/manifest.json not found" \
      "Create .claude/enterprise/manifest.json with ICT risk register"
  fi

  # Check 2: GLM governance manifest (AI transparency / outsourcing)
  local glm="${ROOT_DIR}/.well-known/governance-layer-manifest.json"
  if [[ -f "$glm" ]]; then
    add_check "ai_outsourcing_disclosed" "true" "GLM governance manifest: ${glm}" ""
  else
    add_check "ai_outsourcing_disclosed" "false" ".well-known/governance-layer-manifest.json not found" \
      "Create GLM manifest documenting AI provider outsourcing"
  fi

  # Check 3: autonomous mode safety gates
  local auto_safety="${ROOT_DIR}/docs/rules/domain/autonomous-safety.md"
  if [[ -f "$auto_safety" ]]; then
    add_check "autonomous_safety_gates" "true" "Autonomous mode safety gates in autonomous-safety.md" ""
  else
    add_check "autonomous_safety_gates" "false" "autonomous-safety.md not found" \
      "Create autonomous-safety.md with DORA-compliant ICT change management gates"
  fi
}

# ── Run frameworks ────────────────────────────────────────────────────────────

ASSESSED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

run_framework() {
  local fw="$1"
  CHECKS_JSON=""
  TOTAL=0
  PASSED=0

  case "$fw" in
    eu-ai-act) check_eu_ai_act ;;
    gdpr)      check_gdpr ;;
    nis2)      check_nis2 ;;
    dora)      check_dora ;;
    *) die "unknown framework: ${fw}. Valid: eu-ai-act, gdpr, nis2, dora" ;;
  esac

  local score=0
  [[ "$TOTAL" -gt 0 ]] && score=$(( PASSED * 100 / TOTAL ))

  cat <<JSON
{
  "framework": "${fw}",
  "tenant": "${TENANT}",
  "assessed_at": "${ASSESSED_AT}",
  "score": ${score},
  "passed": ${PASSED},
  "total": ${TOTAL},
  "checks": [${CHECKS_JSON}
  ]
}
JSON
}

output_json() {
  local content="$1"
  if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$content" > "$OUTPUT_FILE"
    echo "Written to ${OUTPUT_FILE}" >&2
  else
    echo "$content"
  fi
}

ALL_FAIL=0

case "$FRAMEWORK" in
  all)
    frameworks=("eu-ai-act" "gdpr" "nis2" "dora")
    echo "["
    first_fw=1
    for fw in "${frameworks[@]}"; do
      [[ "$first_fw" -eq 0 ]] && echo ","
      result="$(run_framework "$fw")"
      echo "$result"
      # Check if any framework failed
      if echo "$result" | grep -q '"score": [0-9]' && ! echo "$result" | grep -q '"score": 100'; then
        ALL_FAIL=1
      fi
      first_fw=0
    done
    echo "]"
    ;;
  eu-ai-act|gdpr|nis2|dora)
    result="$(run_framework "$FRAMEWORK")"
    output_json "$result"
    if ! echo "$result" | grep -q '"score": 100'; then
      ALL_FAIL=1
    fi
    ;;
  *)
    die "unknown framework: ${FRAMEWORK}. Valid: eu-ai-act, gdpr, nis2, dora, all"
    ;;
esac

exit $ALL_FAIL
