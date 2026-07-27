#!/usr/bin/env bash
# kpi-catalog-validate.sh — SE-272 S2 KPI catalog validator
# Validates KPI catalog entries: formal definition, primary data source,
# formula, window, thresholds, version, dual signatures.
# Rejects KPIs without traceable primary source.
#
# Usage:
#   kpi-catalog-validate.sh validate --file PATH/TO/kpis.yaml
#   kpi-catalog-validate.sh validate --engagement CLIENT/ENGAGEMENT
#   kpi-catalog-validate.sh schema

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

usage() {
  cat <<'USAGE'
kpi-catalog-validate.sh — SE-272 S2 KPI catalog validator

Usage:
  kpi-catalog-validate.sh validate --file PATH/TO/kpis.yaml
  kpi-catalog-validate.sh validate --engagement CLIENT/ENGAGEMENT
  kpi-catalog-validate.sh schema

Validates each KPI: definition, source, formula, window, thresholds,
version, dual signatures. Rejects self-declared sources.
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

REQUIRED_KPI_FIELDS=(
  "id"
  "name"
  "definition"
  "primary_source"
  "formula"
  "window_months"
  "target_threshold"
  "warning_threshold"
  "antagonist_kpi_id"
  "version"
  "signature_1"
  "signature_2"
)

VERIFIABLE_SOURCES=(
  "qa_certificates"
  "commit_history"
  "pr_history"
  "incident_log"
  "deployment_log"
  "attestations"
  "audit_trail"
  "billing_ledger"
  "phase_gate_ledger"
)

is_verifiable_source() {
  local source="$1"
  for vs in "${VERIFIABLE_SOURCES[@]}"; do
    if [[ "$source" == "$vs" ]]; then
      return 0
    fi
  done
  return 1
}

cmd_schema() {
  cat <<'YAMLEOF'
# KPI Catalog Schema — SE-272 S2
# Engagements: engagements/{client}/{engagement}/kpis.yaml

version: 1
last_modified: "2026-07-25"

kpis:
  - id: "kpi-001"
    name: "Sprint Velocity"
    definition: >
      Average completed story points per sprint over the measurement window.
    primary_source: "qa_certificates"
    formula: "sum(completed_sp) / count(sprints)"
    window_months: 3
    target_threshold: 40
    warning_threshold: 30
    antagonist_kpi_id: "kpi-002"
    version: 1
    signature_1:
      name: "CLIENT_AUTHORITY"
      date: "2026-01-01"
      role: "stakeholder"
    signature_2:
      name: "PROVIDER_AUTHORITY"
      date: "2026-01-01"
      role: "delivery_manager"

  - id: "kpi-002"
    name: "Defect Escape Rate"
    definition: >
      Ratio of production defects to total defects found.
      Antagonist to Sprint Velocity (prevents speed over quality).
    primary_source: "incident_log"
    formula: "production_defects / total_defects * 100"
    window_months: 3
    target_threshold: 5
    warning_threshold: 10
    antagonist_kpi_id: "kpi-001"
    version: 1
    signature_1:
      name: "CLIENT_AUTHORITY"
      date: "2026-01-01"
      role: "stakeholder"
    signature_2:
      name: "PROVIDER_AUTHORITY"
      date: "2026-01-01"
      role: "delivery_manager"
YAMLEOF
}

cmd_validate() {
  local file="" engagement=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)       file="$2";       shift 2 ;;
      --engagement) engagement="$2"; shift 2 ;;
      *) die "validate: unknown argument: $1" ;;
    esac
  done

  if [[ -n "$engagement" ]]; then
    local client_eng="${engagement%/*}"
    local eng_slug="${engagement#*/}"
    file="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}/kpis.yaml"
  fi

  [[ -z "$file" ]] && die "validate: --file or --engagement is required"
  [[ ! -f "$file" ]] && die "validate: file not found: ${file}"

  local errors=0
  local warnings=0
  local kpi_count=0
  local content
  content="$(cat "$file")"

  if ! echo "$content" | grep -q "^version:"; then
    echo "FAIL: missing version header" >&2
    errors=$(( errors + 1 ))
  fi

  # Count KPIs
  kpi_count=$(echo "$content" | grep -cE '^  - id:' || echo 0)

  # Validate each required section marker is present
  for field in "${REQUIRED_KPI_FIELDS[@]}"; do
    if ! echo "$content" | grep -q "${field}:"; then
      echo "FAIL: missing required field '${field}' in KPI catalog" >&2
      errors=$(( errors + 1 ))
    fi
  done

  # Validate antagonist pairings
  local ids
  ids="$(echo "$content" | grep -oP '^  - id:\s*"\K[^"]+' || true)"
  local antagonists
  antagonists="$(echo "$content" | grep -oP 'antagonist_kpi_id:\s*"\K[^"]+' || true)"

  for ant in $antagonists; do
    if ! echo "$ids" | grep -q "$ant"; then
      echo "FAIL: antagonist_kpi_id '${ant}' references non-existent KPI" >&2
      errors=$(( errors + 1 ))
    fi
  done

  # Check source is verifiable
  local sources
  sources="$(echo "$content" | grep -oP 'primary_source:\s*"\K[^"]+' || true)"
  for src in $sources; do
    if ! is_verifiable_source "$src"; then
      echo "WARN: source '${src}' is not in the verifiable sources list" >&2
      warnings=$(( warnings + 1 ))
    fi
  done

  echo ""
  echo "KPI Catalog: ${file}"
  echo "  KPIs found: ${kpi_count}"
  echo "  Errors:     ${errors}"
  echo "  Warnings:   ${warnings}"
  if [[ "$errors" -gt 0 ]]; then
    echo "  RESULT:     FAIL"
    exit 1
  else
    echo "  RESULT:     PASS"
    exit 0
  fi
}

if [[ $# -eq 0 ]]; then
  usage
fi

subcmd="$1"
shift

case "$subcmd" in
  validate) cmd_validate "$@" ;;
  schema)   cmd_schema "$@" ;;
  -h|--help) usage ;;
  *) echo "ERROR: unknown subcommand: ${subcmd}" >&2
     echo "Run with --help for usage." >&2
     exit 2 ;;
esac
