#!/usr/bin/env bash
# kpi-custody-chain.sh — SE-272 S2 KPI custody chain
# Each KPI report is hash-chained to the previous one.
# Altering a past period breaks chain verification.
#
# Usage:
#   kpi-custody-chain.sh append
#     --engagement CLIENT/ENGAGEMENT
#     --period YYYY-MM
#     [--data-file PATH/TO/raw-data.json]
#   kpi-custody-chain.sh verify
#     --engagement CLIENT/ENGAGEMENT
#   kpi-custody-chain.sh status
#     --engagement CLIENT/ENGAGEMENT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

usage() {
  cat <<'USAGE'
kpi-custody-chain.sh — SE-272 S2 KPI custody chain

Usage:
  kpi-custody-chain.sh append
    --engagement CLIENT/ENGAGEMENT
    --period YYYY-MM
    [--data-file PATH/TO/raw-data.json]

  kpi-custody-chain.sh verify
    --engagement CLIENT/ENGAGEMENT

  kpi-custody-chain.sh status
    --engagement CLIENT/ENGAGEMENT

Hash-chained KPI reports. Tampering detection via SHA256 chain.
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

get_prev_hash() {
  local file="$1"
  if [[ ! -f "$file" ]] || [[ ! -s "$file" ]]; then
    echo "0000000000000000000000000000000000000000000000000000000000000000"
    return
  fi
  local h
  h="$(grep -o '"hash":"[^"]*"' "$file" | tail -1 | cut -d'"' -f4)"
  h="${h:-0000000000000000000000000000000000000000000000000000000000000000}"
  h="${h#sha256:}"
  echo "$h"
}

# ── Subcommand: append ──────────────────────────────────────────────

cmd_append() {
  local engagement="" period="" data_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement) engagement="$2"; shift 2 ;;
      --period)     period="$2";     shift 2 ;;
      --data-file)  data_file="$2";  shift 2 ;;
      *) die "append: unknown argument: $1" ;;
    esac
  done

  [[ -z "$engagement" ]] && die "append: --engagement is required"
  [[ -z "$period"     ]] && die "append: --period is required"

  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local eng_dir="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}"
  mkdir -p "$eng_dir"
  local chain_file="${eng_dir}/kpi-chain.jsonl"
  local pkg_dir="${REPO_ROOT}/output/kpi/${client_eng}/${eng_slug}/${period}"

  # Get data hash from package or generate it
  local data_hash
  if [[ -n "$data_file" ]] && [[ -f "$data_file" ]]; then
    data_hash="sha256:$(sha256_str "$(cat "$data_file")")"
  elif [[ -f "${pkg_dir}/raw-data.json" ]]; then
    data_hash="sha256:$(sha256_str "$(cat "${pkg_dir}/raw-data.json")")"
  elif [[ -f "${pkg_dir}/package.json" ]]; then
    data_hash="$(grep -o '"package_hash":"[^"]*"' "${pkg_dir}/package.json" | head -1 | cut -d'"' -f4)"
  else
    data_hash="sha256:$(echo "no-data-${period}" | sha256sum | cut -d' ' -f1)"
  fi

  local ts
  ts="$(timestamp_utc)"
  local prev_hash
  prev_hash="$(get_prev_hash "$chain_file")"

  local chain_input="${ts}${engagement}${period}${data_hash}${prev_hash}"
  local hash
  hash="sha256:$(sha256_str "$chain_input")"

  local entry
  entry="{\"ts\":\"${ts}\",\"engagement\":\"${engagement}\",\"period\":\"${period}\",\"data_hash\":\"${data_hash}\",\"prev_hash\":\"${prev_hash}\",\"hash\":\"${hash}\"}"

  echo "$entry" >> "$chain_file"

  printf '{\n'
  printf '  "ts": "%s",\n' "$ts"
  printf '  "engagement": "%s",\n' "$engagement"
  printf '  "period": "%s",\n' "$period"
  printf '  "data_hash": "%s",\n' "$data_hash"
  printf '  "prev_hash": "%s",\n' "$prev_hash"
  printf '  "hash": "%s"\n' "$hash"
  printf '}\n'

  echo "OK: chain entry appended"
  echo "    File: ${chain_file}"
}

# ── Subcommand: verify ──────────────────────────────────────────────

cmd_verify() {
  local engagement=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement) engagement="$2"; shift 2 ;;
      *) die "verify: unknown argument: $1" ;;
    esac
  done

  [[ -z "$engagement" ]] && die "verify: --engagement is required"

  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local chain_file="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}/kpi-chain.jsonl"

  if [[ ! -f "$chain_file" ]]; then
    echo "No chain found at ${chain_file}"
    exit 1
  fi

  local prev_hash="0000000000000000000000000000000000000000000000000000000000000000"
  local line_num=0 tampered=0 total=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    line_num=$(( line_num + 1 ))
    total=$(( total + 1 ))

    local entry_ts entry_eng entry_period entry_data_hash stored_prev stored_hash
    entry_ts="$(echo "$line"      | grep -o '"ts":"[^"]*"'         | head -1 | cut -d'"' -f4)"
    entry_eng="$(echo "$line"     | grep -o '"engagement":"[^"]*"' | head -1 | cut -d'"' -f4)"
    entry_period="$(echo "$line"  | grep -o '"period":"[^"]*"'     | head -1 | cut -d'"' -f4)"
    entry_data_hash="$(echo "$line" | grep -o '"data_hash":"[^"]*"' | head -1 | cut -d'"' -f4)"
    stored_prev="$(echo "$line"    | grep -o '"prev_hash":"[^"]*"'  | head -1 | cut -d'"' -f4)"
    stored_hash="$(echo "$line"    | grep -o '"hash":"[^"]*"'       | head -1 | cut -d'"' -f4)"

    local chain_input="${entry_ts}${entry_eng}${entry_period}${entry_data_hash}${prev_hash}"
    local expected_hash="sha256:$(sha256_str "$chain_input")"

    if [[ "${stored_prev}" != "${prev_hash}" ]]; then
      echo "TAMPERED: line ${line_num} — prev_hash mismatch"
      echo "  Expected: ${prev_hash}"
      echo "  Got:      ${stored_prev}"
      tampered=$(( tampered + 1 ))
    fi

    if [[ "${stored_hash}" != "${expected_hash}" ]]; then
      echo "TAMPERED: line ${line_num} — hash mismatch"
      echo "  Expected: ${expected_hash}"
      echo "  Got:      ${stored_hash}"
      tampered=$(( tampered + 1 ))
    fi

    prev_hash="${stored_hash#sha256:}"
  done < "$chain_file"

  echo "Verified ${total} entries"
  if [[ "$tampered" -eq 0 ]]; then
    echo "CHAIN OK"
  else
    echo "CHAIN FAIL: ${tampered} violation(s)"
    exit 1
  fi
}

# ── Subcommand: status ──────────────────────────────────────────────

cmd_status() {
  local engagement=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement) engagement="$2"; shift 2 ;;
      *) die "status: unknown argument: $1" ;;
    esac
  done

  [[ -z "$engagement" ]] && die "status: --engagement is required"

  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local chain_file="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}/kpi-chain.jsonl"

  if [[ ! -f "$chain_file" ]]; then
    echo "No chain found at ${chain_file}"
    exit 0
  fi

  local count
  count="$(grep -c . "$chain_file" 2>/dev/null || echo 0)"
  local last_hash
  last_hash="$(get_prev_hash "$chain_file")"

  echo "Engagement: ${engagement}"
  echo "Entries:    ${count}"
  echo "Last hash:  sha256:${last_hash:0:32}..."
  echo ""

  echo "Periods:"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local p h
    p="$(echo "$line" | grep -o '"period":"[^"]*"'   | head -1 | cut -d'"' -f4)"
    h="$(echo "$line" | grep -o '"hash":"[^"]*"'     | head -1 | cut -d'"' -f4)"
    printf "  %-10s %s\n" "$p" "${h:0:20}..."
  done < "$chain_file"
}

# ── Dispatch ─────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then usage; fi

subcmd="$1"; shift

case "$subcmd" in
  append)  cmd_append "$@" ;;
  verify)  cmd_verify "$@" ;;
  status)  cmd_status "$@" ;;
  -h|--help) usage ;;
  *) echo "ERROR: unknown subcommand: ${subcmd}" >&2; exit 2 ;;
esac
