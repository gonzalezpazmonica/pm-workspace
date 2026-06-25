#!/usr/bin/env bash
# compliance-evidence-collector.sh — SPEC-SE-026 Automated Compliance Evidence Collector
set -uo pipefail
#
# Recopila evidencias de compliance automaticamente desde artefactos del workspace.
#
# Para cada framework: extrae artefactos del workspace como evidencia.
#   eu-ai-act: model cards, audit trail, test results, bias reports
#   iso-9001:  quality gates, review logs, change management
#   dora:      incident log, recovery time, outsourcing register
#   nis2:      security posture, incident log, patch policy
#
# Output:
#   output/compliance-evidence/{date}/{framework}/evidence-bundle/  (collected artifacts)
#   output/compliance-evidence/{date}/index.json  (index with {framework, artifacts, generated_at})
#
# Reference: SPEC-SE-026

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_BASE="${ROOT_DIR}/output/compliance-evidence"

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
compliance-evidence-collector.sh — SPEC-SE-026 Evidence Collector

Usage:
  compliance-evidence-collector.sh [--framework FRAMEWORK] [--tenant SLUG] [--date DATE]
  compliance-evidence-collector.sh --help

Options:
  --framework  Framework: eu-ai-act, iso-9001, dora, nis2, all (default: all)
  --tenant     Tenant slug for scoped collection (default: default)
  --date       Collection date tag YYYY-MM-DD (default: today)

Output:
  output/compliance-evidence/{date}/index.json
  output/compliance-evidence/{date}/{framework}/evidence-bundle/ (artifacts)
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

FRAMEWORK="all"
TENANT="default"
DATE="$(date +%Y-%m-%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --framework) FRAMEWORK="$2"; shift 2 ;;
    --tenant)    TENANT="$2";    shift 2 ;;
    --date)      DATE="$2";      shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RUN_DIR="${OUTPUT_BASE}/${DATE}"
INDEX_FILE="${RUN_DIR}/index.json"

mkdir -p "$RUN_DIR"

FRAMEWORKS_JSON=""
ARTIFACTS_COLLECTED=0

# ── Evidence collection per framework ────────────────────────────────────────

collect_framework() {
  local fw="$1"
  local fw_dir="${RUN_DIR}/${fw}/evidence-bundle"
  mkdir -p "$fw_dir"

  local artifacts_list=""
  local count=0

  add_artifact() {
    local src="$1" label="$2"
    local sep=""
    [[ -n "$artifacts_list" ]] && sep=","
    if [[ -f "$src" ]]; then
      local dst="${fw_dir}/$(basename "$src")"
      cp "$src" "$dst" 2>/dev/null || true
      artifacts_list="${artifacts_list}${sep}{\"label\":\"${label}\",\"source\":\"${src}\",\"collected\":true}"
      count=$(( count + 1 ))
    elif [[ -d "$src" ]]; then
      # Directory: copy its files
      while IFS= read -r f; do
        local dst="${fw_dir}/$(basename "$f")"
        cp "$f" "$dst" 2>/dev/null || true
        artifacts_list="${artifacts_list}${sep}{\"label\":\"${label}: $(basename "$f")\",\"source\":\"${f}\",\"collected\":true}"
        sep=","
        count=$(( count + 1 ))
      done < <(find "$src" -maxdepth 1 -name "*.md" -o -name "*.json" -o -name "*.jsonl" 2>/dev/null)
    else
      artifacts_list="${artifacts_list}${sep}{\"label\":\"${label}\",\"source\":\"${src}\",\"collected\":false,\"gap\":\"not found\"}"
    fi
  }

  case "$fw" in
    eu-ai-act)
      add_artifact "${ROOT_DIR}/.claude/enterprise/model-cards" "AI Act Model Cards"
      add_artifact "${ROOT_DIR}/.claude/enterprise/audit" "Signed Audit Trail"
      add_artifact "${ROOT_DIR}/docs/rules/domain/enterprise-governance-protocol.md" "Governance Protocol"
      add_artifact "${ROOT_DIR}/docs/rules/domain/autonomous-safety.md" "Human Oversight Gates"
      add_artifact "${ROOT_DIR}/.well-known/governance-layer-manifest.json" "GLM Governance Manifest"
      add_artifact "${ROOT_DIR}/docs/rules/domain/equality-shield.md" "Bias Testing Policy"
      add_artifact "${ROOT_DIR}/.claude/enterprise/manifest.json" "Enterprise Module Registry"
      ;;
    iso-9001)
      add_artifact "${ROOT_DIR}/docs/propuestas" "Spec Change Management (ISO 8.5.1)"
      add_artifact "${ROOT_DIR}/docs/rules/domain/autonomous-safety.md" "Controlled Delivery (ISO 8.5)"
      add_artifact "${ROOT_DIR}/docs/rules/domain/enterprise-governance-protocol.md" "Quality Gates"
      add_artifact "${ROOT_DIR}/output" "Delivery Outputs (ISO 8.7)"
      ;;
    dora)
      add_artifact "${ROOT_DIR}/.claude/enterprise/manifest.json" "ICT Risk Register"
      add_artifact "${ROOT_DIR}/.well-known/governance-layer-manifest.json" "AI Outsourcing Disclosure"
      add_artifact "${ROOT_DIR}/docs/rules/domain/autonomous-safety.md" "ICT Change Management"
      add_artifact "${ROOT_DIR}/output/postmortems" "Incident Log"
      ;;
    nis2)
      add_artifact "${ROOT_DIR}/docs/savia-shield.md" "Security Posture"
      add_artifact "${ROOT_DIR}/output/postmortems" "Incident Log"
      add_artifact "${ROOT_DIR}/.claude/enterprise/audit" "Audit Trail"
      add_artifact "${ROOT_DIR}/docs/rules/domain/enterprise-governance-protocol.md" "Security Controls"
      ;;
    *)
      die "unknown framework: ${fw}. Valid: eu-ai-act, iso-9001, dora, nis2"
      ;;
  esac

  ARTIFACTS_COLLECTED=$(( ARTIFACTS_COLLECTED + count ))

  local sep=""
  [[ -n "$FRAMEWORKS_JSON" ]] && sep=","
  FRAMEWORKS_JSON="${FRAMEWORKS_JSON}${sep}{\"framework\":\"${fw}\",\"artifacts_collected\":${count},\"bundle_dir\":\"${fw_dir}\",\"artifacts\":[${artifacts_list}]}"
}

# ── Run collection ────────────────────────────────────────────────────────────

case "$FRAMEWORK" in
  all)
    for fw in eu-ai-act iso-9001 dora nis2; do
      echo "  Collecting ${fw}..."
      collect_framework "$fw"
    done
    ;;
  eu-ai-act|iso-9001|dora|nis2)
    collect_framework "$FRAMEWORK"
    ;;
  *)
    die "unknown framework: ${FRAMEWORK}. Valid: eu-ai-act, iso-9001, dora, nis2, all"
    ;;
esac

# ── Write index.json ─────────────────────────────────────────────────────────

cat > "$INDEX_FILE" <<JSON
{
  "generated_at": "${GENERATED_AT}",
  "date": "${DATE}",
  "tenant": "${TENANT}",
  "framework": "${FRAMEWORK}",
  "artifacts_total": ${ARTIFACTS_COLLECTED},
  "run_dir": "${RUN_DIR}",
  "frameworks": [${FRAMEWORKS_JSON}]
}
JSON

echo "OK: evidence collected — ${ARTIFACTS_COLLECTED} artifacts"
echo "    index: ${INDEX_FILE}"
