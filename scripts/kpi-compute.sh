#!/usr/bin/env bash
# kpi-compute.sh — SE-272 S2 KPI computation from verifiable artifacts
# Computes KPIs from primary sources (QA certs, commits, PRs,
# incidents, attestations). Never from self-declared data.
# Outputs raw data package for client recomputation.
#
# Usage:
#   kpi-compute.sh compute --kpi-id KPI_ID --engagement CLIENT/ENGAGEMENT
#     [--window-start DATE] [--window-end DATE]
#   kpi-compute.sh compute-all --engagement CLIENT/ENGAGEMENT
#   kpi-compute.sh export-package --engagement CLIENT/ENGAGEMENT --period YYYY-MM

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

usage() {
  cat <<'USAGE'
kpi-compute.sh — SE-272 S2 KPI computation from verifiable artifacts

Usage:
  kpi-compute.sh compute --kpi-id ID --engagement CLIENT/ENGAGEMENT
  kpi-compute.sh compute-all --engagement CLIENT/ENGAGEMENT
  kpi-compute.sh export-package --engagement CLIENT/ENGAGEMENT --period YYYY-MM

Computes KPIs from traceable primary sources only.
Outputs raw data package for independent recomputation.
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

sha256_str() {
  printf '%s' "$1" | sha256sum | cut -d' ' -f1
}

timestamp_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# ── Source-specific computation functions ───────────────────────────

compute_from_qa_certs() {
  local engagement="$1"
  local cert_dir="${REPO_ROOT}/engagements/${engagement%/*}/${engagement#*/}/qa"
  if [[ -d "$cert_dir" ]]; then
    find "$cert_dir" -type f -name "*.json" | wc -l
  else
    echo "0"
  fi
}

compute_from_commits() {
  local window_start="${1:-}" window_end="${2:-}"
  if [[ -d "${REPO_ROOT}/.git" ]]; then
    if [[ -n "$window_start" ]] && [[ -n "$window_end" ]]; then
      git -C "$REPO_ROOT" log --oneline --after="${window_start}" --before="${window_end}" 2>/dev/null | wc -l
    else
      git -C "$REPO_ROOT" log --oneline --since="1 month ago" 2>/dev/null | wc -l
    fi
  else
    echo "0"
  fi
}

compute_from_prs() {
  local window_start="${1:-}" window_end="${2:-}"
  if [[ -d "${REPO_ROOT}/.git" ]]; then
    if [[ -n "$window_start" ]] && [[ -n "$window_end" ]]; then
      git -C "$REPO_ROOT" log --oneline --merges --after="${window_start}" --before="${window_end}" 2>/dev/null | wc -l
    else
      git -C "$REPO_ROOT" log --oneline --merges --since="1 month ago" 2>/dev/null | wc -l
    fi
  else
    echo "0"
  fi
}

compute_from_deployments() {
  local engagement="$1"
  local deploy_dir="${REPO_ROOT}/engagements/${engagement%/*}/${engagement#*/}/deployments"
  if [[ -d "$deploy_dir" ]]; then
    find "$deploy_dir" -type f -name "*.json" | wc -l
  else
    echo "0"
  fi
}

compute_from_incidents() {
  local engagement="$1" window_start="${2:-}" window_end="${3:-}"
  local incident_file="${REPO_ROOT}/engagements/${engagement%/*}/${engagement#*/}/incidents.jsonl"
  if [[ -f "$incident_file" ]]; then
    if [[ -n "$window_start" ]] && [[ -n "$window_end" ]]; then
      grep -c . "$incident_file" 2>/dev/null || echo 0
    else
      grep -c . "$incident_file" 2>/dev/null || echo 0
    fi
  else
    echo "0"
  fi
}

# ── Subcommand: compute ─────────────────────────────────────────────

cmd_compute() {
  local kpi_id="" engagement="" window_start="" window_end=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --kpi-id)       kpi_id="$2";       shift 2 ;;
      --engagement)   engagement="$2";   shift 2 ;;
      --window-start) window_start="$2"; shift 2 ;;
      --window-end)   window_end="$2";   shift 2 ;;
      *) die "compute: unknown argument: $1" ;;
    esac
  done

  [[ -z "$kpi_id"     ]] && die "compute: --kpi-id is required"
  [[ -z "$engagement" ]] && die "compute: --engagement is required"

  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local kpis_file="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}/kpis.yaml"

  [[ ! -f "$kpis_file" ]] && die "compute: KPI catalog not found: ${kpis_file}"

  local content
  content="$(cat "$kpis_file")"

  local name source formula
  name="$(echo "$content" | grep -A20 "id: \"${kpi_id}\"" | grep "name:" | head -1 | sed 's/.*name: *"//;s/"$//')"
  source="$(echo "$content" | grep -A20 "id: \"${kpi_id}\"" | grep "primary_source:" | head -1 | sed 's/.*primary_source: *"//;s/"$//')"
  formula="$(echo "$content" | grep -A20 "id: \"${kpi_id}\"" | grep "formula:" | head -1 | sed 's/.*formula: *"//;s/"$//')"

  [[ -z "$source" ]] && die "compute: KPI '${kpi_id}' has no primary_source defined"

  local value="0"
  case "$source" in
    qa_certificates)  value=$(compute_from_qa_certs "$engagement") ;;
    commit_history)   value=$(compute_from_commits "$window_start" "$window_end") ;;
    pr_history)       value=$(compute_from_prs "$window_start" "$window_end") ;;
    deployment_log)   value=$(compute_from_deployments "$engagement") ;;
    incident_log)     value=$(compute_from_incidents "$engagement" "$window_start" "$window_end") ;;
    *) die "compute: unknown source type '${source}' for KPI '${kpi_id}'" ;;
  esac

  local ts
  ts="$(timestamp_utc)"
  local period="${window_start:-N/A} to ${window_end:-N/A}"

  printf '{\n'
  printf '  "computed_at": "%s",\n' "$ts"
  printf '  "kpi_id": "%s",\n' "$kpi_id"
  printf '  "kpi_name": "%s",\n' "$name"
  printf '  "engagement": "%s",\n' "$engagement"
  printf '  "formula": "%s",\n' "$formula"
  printf '  "primary_source": "%s",\n' "$source"
  printf '  "period": "%s",\n' "$period"
  printf '  "raw_value": %s,\n' "$value"
  printf '  "unit": "count"\n'
  printf '}\n'
}

# ── Subcommand: compute-all ─────────────────────────────────────────

cmd_compute_all() {
  local engagement="" window_start="" window_end=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement)   engagement="$2";   shift 2 ;;
      --window-start) window_start="$2"; shift 2 ;;
      --window-end)   window_end="$2";   shift 2 ;;
      *) die "compute-all: unknown argument: $1" ;;
    esac
  done

  [[ -z "$engagement" ]] && die "compute-all: --engagement is required"

  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local kpis_file="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}/kpis.yaml"

  [[ ! -f "$kpis_file" ]] && die "compute-all: KPI catalog not found: ${kpis_file}"

  local ids
  ids="$(grep -o 'id: "[^"]*"' "$kpis_file" | sed 's/id: "//;s/"$//' || true)"

  if [[ -z "$ids" ]]; then
    echo "No KPIs found in catalog"
    exit 0
  fi

  local ts
  ts="$(timestamp_utc)"

  printf '{\n'
  printf '  "computed_at": "%s",\n' "$ts"
  printf '  "engagement": "%s",\n' "$engagement"
  printf '  "period": "%s to %s",\n' "${window_start:-N/A}" "${window_end:-N/A}"
  printf '  "results": [\n'

  local first=1
  for id in $ids; do
    if [[ "$first" -eq 0 ]]; then printf '    ,\n'; fi
    local name source formula
    name="$(grep -A20 "id: \"${id}\"" "$kpis_file" | grep "name:" | head -1 | sed 's/.*name: *"//;s/"$//')"
    source="$(grep -A20 "id: \"${id}\"" "$kpis_file" | grep "primary_source:" | head -1 | sed 's/.*primary_source: *"//;s/"$//')"

    local value="0"
    case "${source:-unknown}" in
      qa_certificates)  value=$(compute_from_qa_certs "$engagement") ;;
      commit_history)   value=$(compute_from_commits "$window_start" "$window_end") ;;
      pr_history)       value=$(compute_from_prs "$window_start" "$window_end") ;;
      deployment_log)   value=$(compute_from_deployments "$engagement") ;;
      incident_log)     value=$(compute_from_incidents "$engagement" "$window_start" "$window_end") ;;
    esac

    printf '    {\n'
    printf '      "kpi_id": "%s",\n' "$id"
    printf '      "kpi_name": "%s",\n' "$name"
    printf '      "primary_source": "%s",\n' "$source"
    printf '      "raw_value": %s\n' "$value"
    printf '    }'
    first=0
  done

  printf '\n  ]\n'
  printf '}\n'
}

# ── Subcommand: export-package ──────────────────────────────────────

cmd_export_package() {
  local engagement="" period=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement) engagement="$2"; shift 2 ;;
      --period)     period="$2";     shift 2 ;;
      *) die "export-package: unknown argument: $1" ;;
    esac
  done

  [[ -z "$engagement" ]] && die "export-package: --engagement is required"
  [[ -z "$period"     ]] && die "export-package: --period is required"

  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local output_dir="${REPO_ROOT}/output/kpi/${client_eng}/${eng_slug}/${period}"
  mkdir -p "$output_dir"

  local ts
  ts="$(timestamp_utc)"
  local results
  results="$("$0" compute-all --engagement "$engagement")"

  echo "$results" > "${output_dir}/raw-data.json"

  local pkg_hash
  pkg_hash="sha256:$(sha256_str "$results")"

  printf '{\n' > "${output_dir}/package.json"
  printf '  "engagement": "%s",\n' "$engagement" >> "${output_dir}/package.json"
  printf '  "period": "%s",\n' "$period" >> "${output_dir}/package.json"
  printf '  "generated_at": "%s",\n' "$ts" >> "${output_dir}/package.json"
  printf '  "package_hash": "%s",\n' "$pkg_hash" >> "${output_dir}/package.json"
  printf '  "files": ["raw-data.json", "package.json"]\n' >> "${output_dir}/package.json"
  printf '}\n' >> "${output_dir}/package.json"

  echo "Package exported: ${output_dir}"
  echo "  Hash: ${pkg_hash}"
}

# ── Dispatch ─────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then usage; fi

subcmd="$1"; shift

case "$subcmd" in
  compute)        cmd_compute "$@" ;;
  compute-all)    cmd_compute_all "$@" ;;
  export-package) cmd_export_package "$@" ;;
  -h|--help)      usage ;;
  *) echo "ERROR: unknown subcommand: ${subcmd}" >&2; exit 2 ;;
esac
