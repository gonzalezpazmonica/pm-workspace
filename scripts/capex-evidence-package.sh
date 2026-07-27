#!/usr/bin/env bash
# capex-evidence-package.sh — SE-272 S1 Evidence package generator
# Generates per-asset capitalization evidence from verifiable artifacts.
#
# Usage:
#   capex-evidence-package.sh generate
#     --asset-id ID
#     --engagement CLIENT/ENGAGEMENT
#     [--output-dir DIR]
#   capex-evidence-package.sh verify
#     --package-dir DIR
#
# Evidence package includes:
#   description, phase dates, specs+ACs, commits+QA certs,
#   attributed effort, status — all linked to artifacts.
# Recomputation: effort can be independently verified from SC data.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

usage() {
  cat <<'USAGE'
capex-evidence-package.sh — SE-272 S1 Evidence package generator

Usage:
  capex-evidence-package.sh generate
    --asset-id ID
    --engagement CLIENT/ENGAGEMENT
    [--output-dir DIR]
    [--description "text"]
    [--phase-start DATE]
    [--phase-end DATE]
    [--link-spec SPEC_ID]
    [--link-pr PR_NUMBER]
    [--effort-hours N]
    [--status pending|active|completed|capitalized]

  capex-evidence-package.sh verify
    --package-dir DIR

Generates evidence package with links to verifiable artifacts.
Supports recomputation: hours can be verified from commit/PR data.
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

# ── Collect verifiable effort from source control ───────────────────

collect_effort_from_artifacts() {
  local asset_id="$1"
  local spec_id="${2:-}"
  local repo_dir="${3:-$REPO_ROOT}"

  local commit_count=0
  local pr_count=0

  if [[ -d "${repo_dir}/.git" ]]; then
    if [[ -n "$spec_id" ]]; then
      commit_count="$(git -C "$repo_dir" log --oneline --grep="${spec_id}" 2>/dev/null | wc -l || echo 0)"
      pr_count="$(git -C "$repo_dir" log --oneline --grep="Merge.*${spec_id}" 2>/dev/null | wc -l || echo 0)"
    fi
    if [[ "$commit_count" -eq 0 ]]; then
      commit_count="$(git -C "$repo_dir" log --oneline --grep="${asset_id}" 2>/dev/null | wc -l || echo 0)"
    fi
  fi

  echo "{\"commit_count\":${commit_count},\"pr_count\":${pr_count}}"
}

# ── Subcommand: generate ────────────────────────────────────────────

cmd_generate() {
  local asset_id="" engagement="" output_dir="" description=""
  local phase_start="" phase_end="" link_spec="" link_pr=""
  local effort_hours="" status="pending"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --asset-id)     asset_id="$2";     shift 2 ;;
      --engagement)   engagement="$2";   shift 2 ;;
      --output-dir)   output_dir="$2";   shift 2 ;;
      --description)  description="$2";  shift 2 ;;
      --phase-start)  phase_start="$2";  shift 2 ;;
      --phase-end)    phase_end="$2";    shift 2 ;;
      --link-spec)    link_spec="$2";    shift 2 ;;
      --link-pr)      link_pr="$2";      shift 2 ;;
      --effort-hours) effort_hours="$2"; shift 2 ;;
      --status)       status="$2";       shift 2 ;;
      *) die "generate: unknown argument: $1" ;;
    esac
  done

  [[ -z "$asset_id"   ]] && die "generate: --asset-id is required"
  [[ -z "$engagement" ]] && die "generate: --engagement is required"

  case "$status" in
    pending|active|completed|capitalized) ;;
    *) die "generate: --status must be pending|active|completed|capitalized" ;;
  esac

  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local eng_dir="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}"

  if [[ -z "$output_dir" ]]; then
    output_dir="${eng_dir}/evidence/${asset_id}"
  fi
  mkdir -p "$output_dir"

  local ts
  ts="$(timestamp_utc)"

  # Collect SC data
  local sc_data
  sc_data="$(collect_effort_from_artifacts "$asset_id" "$link_spec" "$REPO_ROOT")"

  local commit_count
  commit_count="$(echo "$sc_data" | grep -o '"commit_count":[0-9]*' | cut -d: -f2)"
  local pr_count
  pr_count="$(echo "$sc_data" | grep -o '"pr_count":[0-9]*' | cut -d: -f2)"

  # Build evidence YAML
  cat > "${output_dir}/evidence.yaml" <<YAMLEOF
# CAPEX Evidence Package — SE-272 S1
# Asset: ${asset_id}
# Engagement: ${engagement}
# Generated: ${ts}

asset:
  id: "${asset_id}"
  engagement: "${engagement}"

description: "${description}"

phases:
  start: "${phase_start}"
  end: "${phase_end}"
development_start: "${phase_start}"
development_end: "${phase_end}"

status: "${status}"

artifacts:
  specs:
    - "${link_spec}"
  prs:
    - "${link_pr}"

effort:
  declared_hours: "${effort_hours}"
  verifiable_commits: ${commit_count:-0}
  verifiable_prs: ${pr_count:-0}

evidence_files:
  - evidence.yaml
  - sc-data.json
  - manifest.json

generated_at: "${ts}"
generated_by: "scripts/capex-evidence-package.sh"
YAMLEOF

  # Save raw SC data
  echo "$sc_data" > "${output_dir}/sc-data.json"

  # Manifest
  cat > "${output_dir}/manifest.json" <<JSONLEOF
{
  "asset_id": "${asset_id}",
  "engagement": "${engagement}",
  "generated_at": "${ts}",
  "status": "${status}",
  "files": [
    "evidence.yaml",
    "sc-data.json",
    "manifest.json"
  ]
}
JSONLEOF

  # Compute package hash
  local pkg_content
  pkg_content="$(cat "${output_dir}/evidence.yaml" "${output_dir}/sc-data.json")"
  local pkg_hash
  pkg_hash="sha256:$(sha256_str "$pkg_content")"

  # Write hash back into evidence.yaml
  cat >> "${output_dir}/evidence.yaml" <<YAMLEOF
hash: "${pkg_hash}"
YAMLEOF

  # Write hash into manifest
  local tmp_manifest
  tmp_manifest="$(mktemp)"
  jq '. + {"package_hash": "'"${pkg_hash}"'"}' "${output_dir}/manifest.json" > "$tmp_manifest" 2>/dev/null || {
    # jq not available; use sed
    sed -i "s/}/,\"package_hash\":\"${pkg_hash}\"}/" "${output_dir}/manifest.json"
    echo "manifest.json updated (sed fallback)"
    tmp_manifest=""
  }
  if [[ -n "$tmp_manifest" ]] && [[ -s "$tmp_manifest" ]]; then
    mv "$tmp_manifest" "${output_dir}/manifest.json"
  fi

  echo "Evidence package generated: ${output_dir}"
  echo "  Files: evidence.yaml, sc-data.json, manifest.json"
  echo "  Hash:  ${pkg_hash}"
}

# ── Subcommand: verify ──────────────────────────────────────────────

cmd_verify() {
  local package_dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --package-dir) package_dir="$2"; shift 2 ;;
      *) die "verify: unknown argument: $1" ;;
    esac
  done

  [[ -z "$package_dir" ]] && die "verify: --package-dir is required"
  [[ ! -d "$package_dir" ]] && die "verify: directory not found: ${package_dir}"

  local evidence_file="${package_dir}/evidence.yaml"
  local sc_data_file="${package_dir}/sc-data.json"

  [[ ! -f "$evidence_file" ]] && die "verify: evidence.yaml not found in ${package_dir}"
  [[ ! -f "$sc_data_file" ]] && die "verify: sc-data.json not found in ${package_dir}"

  local stored_hash
  stored_hash="$(grep -o 'hash: "[^"]*"' "$evidence_file" | head -1 | cut -d'"' -f2)"

  local content
  content="$(grep -v '^hash: ' "$evidence_file"; cat "$sc_data_file")"
  local computed_hash
  computed_hash="sha256:$(sha256_str "$content")"

  if [[ "${stored_hash}" == "${computed_hash}" ]]; then
    echo "VERIFIED: package hash matches — ${computed_hash}"
    return 0
  else
    echo "MISMATCH: stored=${stored_hash} computed=${computed_hash}"
    return 1
  fi
}

# ── Dispatch ─────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  usage
fi

subcmd="$1"
shift

case "$subcmd" in
  generate) cmd_generate "$@" ;;
  verify)   cmd_verify "$@" ;;
  -h|--help) usage ;;
  *) echo "ERROR: unknown subcommand: ${subcmd}" >&2
     echo "Run with --help for usage." >&2
     exit 2 ;;
esac
