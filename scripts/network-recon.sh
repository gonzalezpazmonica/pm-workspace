#!/usr/bin/env bash
# network-recon.sh — SE-246 Network Reconnaissance
# Port scanning and service detection using nmap, RustScan, httpx
# REQUIRES: output/security/authorization-{target}.txt with "AUTHORIZED"
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/output/security"
DATE_STAMP=$(date +%Y%m%d)

TARGET=""
PORTS="--top-1000"
MODE="discovery"

usage() {
  echo "Usage: $0 --target <ip|hostname|cidr> [--ports <range>] [--mode discovery]"
  echo ""
  echo "Options:"
  echo "  --target  Hostname, IP, or CIDR range to scan"
  echo "  --ports   Port range (default: top-1000, e.g. 1-65535, 80,443,8080)"
  echo "  --mode    Scan mode: discovery (default) — enumerate only, no exploitation"
  echo ""
  echo "Requires authorization file: output/security/authorization-{target}.txt"
  echo "Target IPs must be resolved at runtime from local config (never hardcoded)."
  exit 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target) TARGET="$2"; shift 2 ;;
      --ports)  PORTS="$2";  shift 2 ;;
      --mode)   MODE="$2";   shift 2 ;;
      -h|--help) usage ;;
      *) echo "Unknown option: $1"; usage ;;
    esac
  done
  [[ -z "${TARGET}" ]] && { echo "ERROR: --target is required"; usage; }
}

check_authorization() {
  local target="$1"
  local auth_file="${OUTPUT_DIR}/authorization-${target}.txt"

  if [[ ! -f "${auth_file}" ]]; then
    echo "ERROR: Authorization file not found: ${auth_file}"
    echo ""
    echo "Create it with content 'AUTHORIZED' to authorize scanning of '${target}'."
    echo "Only scan infrastructure you own or have explicit written permission to scan."
    exit 1
  fi

  if ! grep -q "AUTHORIZED" "${auth_file}"; then
    echo "ERROR: Authorization file does not contain 'AUTHORIZED': ${auth_file}"
    exit 1
  fi

  local file_epoch
  file_epoch=$(stat -c %Y "${auth_file}" 2>/dev/null || stat -f %m "${auth_file}" 2>/dev/null)
  local now_epoch
  now_epoch=$(date +%s)
  local age=$(( now_epoch - file_epoch ))
  local max_age=$((30 * 24 * 3600))

  if [[ ${age} -gt ${max_age} ]]; then
    echo "ERROR: Authorization file is older than 30 days. Re-authorize."
    exit 1
  fi

  echo "[auth] Authorization verified for target: ${target}"
}

build_nmap_port_arg() {
  local ports="$1"
  if [[ "${ports}" == "--top-1000" ]]; then
    echo "--top-ports 1000"
  else
    echo "-p ${ports}"
  fi
}

run_rustscan_nmap() {
  local target="$1"
  local port_arg="$2"
  local outfile="$3"
  # MODE: discovery — no aggressive flags (-A, -O, --script=exploit)
  # Conservative nmap: -sV -T3, no -A, no -O, no aggressive scripts
  local nmap_safe_args=("-sV" "-T3" "--open" "-oJ" "${outfile}")

  if command -v rustscan &>/dev/null; then
    echo "[rustscan+nmap] Scanning with RustScan..."
    rustscan --batch-size 2500 -a "${target}" -- "${nmap_safe_args[@]}" 2>/dev/null || true
    echo "[rustscan] Done (native binary)"
  elif docker info &>/dev/null 2>&1; then
    echo "[rustscan+nmap] Scanning with RustScan (Docker)..."
    docker run --rm "rustscan/rustscan" --batch-size 2500 -a "${target}" -- "${nmap_safe_args[@]}" 2>/dev/null > "${outfile}" || true
    echo "[rustscan] Done (Docker fallback)"
  elif command -v nmap &>/dev/null; then
    echo "[nmap] Scanning (RustScan unavailable)..."
    # shellcheck disable=SC2086
    nmap ${port_arg} "${nmap_safe_args[@]}" "${target}" 2>/dev/null || true
    echo "[nmap] Done (native binary)"
  elif docker info &>/dev/null 2>&1; then
    echo "[nmap] Scanning via Docker..."
    # shellcheck disable=SC2086
    docker run --rm "instrumentisto/nmap" ${port_arg} "${nmap_safe_args[@]}" "${target}" 2>/dev/null > "${outfile}" || true
    echo "[nmap] Done (Docker fallback)"
  else
    echo "[nmap/rustscan] SKIP — not available"
  fi
}

run_httpx_services() {
  local target="$1"
  local outfile="$2"
  echo "[httpx] Detecting HTTP services..."
  if command -v httpx &>/dev/null; then
    echo "${target}" | httpx -silent -json -status-code -title -tech-detect -o "${outfile}" 2>/dev/null || true
    echo "[httpx] Done (native binary)"
  elif docker info &>/dev/null 2>&1; then
    echo "${target}" | docker run --rm -i "projectdiscovery/httpx" -silent -json -status-code -title -tech-detect 2>/dev/null > "${outfile}" || true
    echo "[httpx] Done (Docker fallback)"
  else
    echo "[httpx] SKIP — not available"
  fi
}

main() {
  parse_args "$@"

  mkdir -p "${OUTPUT_DIR}"

  # Authorization gate
  check_authorization "${TARGET}"

  local report_dir="${OUTPUT_DIR}/network-recon-${TARGET}-${DATE_STAMP}"
  mkdir -p "${report_dir}"

  local services_file="${report_dir}/services.json"
  local http_file="${report_dir}/http-services.json"
  local ports_file="${report_dir}/ports-open.txt"

  echo "[network-recon] Target: ${TARGET}"
  echo "[network-recon] Mode: ${MODE}"
  echo "[network-recon] Ports: ${PORTS}"
  echo "[network-recon] Report: ${report_dir}"

  local port_arg
  port_arg=$(build_nmap_port_arg "${PORTS}")

  # discovery mode: enumerate only, no exploitation
  if [[ "${MODE}" == "discovery" ]]; then
    run_rustscan_nmap "${TARGET}" "${port_arg}" "${services_file}"
    run_httpx_services "${TARGET}" "${http_file}"

    # Extract open ports summary
    if command -v jq &>/dev/null && [[ -f "${services_file}" ]]; then
      jq -r '.[] | .host + ":" + (.ports[]?.port | tostring)' "${services_file}" 2>/dev/null > "${ports_file}" || true
    fi
  else
    echo "ERROR: Unknown mode '${MODE}'. Only 'discovery' is supported."
    exit 1
  fi

  # Build consolidated JSON report
  local report_json="${OUTPUT_DIR}/network-recon-${TARGET}-${DATE_STAMP}.json"
  cat > "${report_json}" <<EOF
{
  "target": "${TARGET}",
  "date": "${DATE_STAMP}",
  "mode": "${MODE}",
  "ports": "${PORTS}",
  "report_dir": "${report_dir}",
  "services_file": "${services_file}",
  "http_services_file": "${http_file}",
  "ports_open_file": "${ports_file}"
}
EOF

  echo "[network-recon] Report written: ${report_json}"
  echo "[network-recon] Done."
}

main "$@"
