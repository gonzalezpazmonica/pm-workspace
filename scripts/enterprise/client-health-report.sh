#!/usr/bin/env bash
# client-health-report.sh — SE-024 Client Health Intelligence
set -uo pipefail
# Generates health report for all clients of a tenant.
#
# Usage:
#   scripts/enterprise/client-health-report.sh --tenant SLUG [--since DATE] [--format table|json]
#
# Iterates over tenants/{tenant}/clients/ and scores each client.
# Output: sorted by score ascending (critical clients first).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

HEALTH_SCORE_SCRIPT="${SCRIPT_DIR}/client-health-score.sh"

TENANT=""
SINCE=""
FORMAT="table"

# ── arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)  TENANT="$2"; shift 2 ;;
    --since)   SINCE="$2";  shift 2 ;;
    --format)  FORMAT="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: client-health-report.sh --tenant SLUG [--since DATE] [--format table|json]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$TENANT" ]]; then
  echo '{"error":"--tenant is required"}' >&2
  exit 2
fi

CLIENTS_DIR="${REPO_ROOT}/tenants/${TENANT}/clients"

# ── collect clients ───────────────────────────────────────────────────────────
declare -a client_slugs=()
if [[ -d "$CLIENTS_DIR" ]]; then
  while IFS= read -r -d '' dir; do
    cslug="$(basename "$dir")"
    client_slugs+=("$cslug")
  done < <(find "$CLIENTS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
fi

# If no real clients directory, generate graceful empty output
if [[ ${#client_slugs[@]} -eq 0 ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    printf '{"tenant":"%s","clients":[],"generated_at":"%s"}\n' \
      "$TENANT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  else
    printf 'Tenant: %s\n' "$TENANT"
    printf 'No clients found.\n'
  fi
  exit 0
fi

# ── score each client ─────────────────────────────────────────────────────────
declare -a scored_lines=()

for cslug in "${client_slugs[@]}"; do
  raw="$("$HEALTH_SCORE_SCRIPT" --client "$cslug" --tenant "$TENANT" --json 2>/dev/null || echo '{}')"
  cscore="$(printf '%s' "$raw" | grep '"score"' | grep -o '[0-9]*' | head -1 || echo 50)"
  crisk="$(printf '%s' "$raw" | grep '"risk"' | cut -d'"' -f4 || echo 'unknown')"
  crec="$(printf '%s' "$raw" | grep '"recommendation"' | cut -d'"' -f4 || echo '')"
  scored_lines+=("${cscore}|${cslug}|${crisk}|${crec}")
done

# Sort by score ascending (critical first)
IFS=$'\n' sorted_lines=($(printf '%s\n' "${scored_lines[@]}" | sort -t'|' -k1 -n))
unset IFS

# ── format output ─────────────────────────────────────────────────────────────
_format_json() {
  printf '{\n'
  printf '  "tenant": "%s",\n' "$TENANT"
  printf '  "generated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "clients": [\n'
  local first=true
  for line in "${sorted_lines[@]}"; do
    IFS='|' read -r cscore cslug crisk crec <<< "$line"
    if [[ "$first" == "true" ]]; then first=false; else printf ',\n'; fi
    printf '    {"client":"%s","score":%s,"risk":"%s","recommendation":"%s"}' \
      "$cslug" "$cscore" "$crisk" "$crec"
  done
  printf '\n  ]\n}\n'
}

if [[ "$FORMAT" == "json" ]]; then
  _format_json
else
  printf '%-30s %6s %-10s %s\n' "CLIENT" "SCORE" "RISK" "RECOMMENDATION"
  printf '%s\n' "$(printf '%0.s-' {1..80})"
  for line in "${sorted_lines[@]}"; do
    IFS='|' read -r cscore cslug crisk crec <<< "$line"
    printf '%-30s %6s %-10s %s\n' "$cslug" "$cscore" "$crisk" "${crec:0:40}"
  done
fi
