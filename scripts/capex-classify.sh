#!/usr/bin/env bash
# capex-classify.sh — SE-272 S1 CAPEX/OPEX classification
# Classifies work nature and records signed confirmation in engagement ledger.
#
# Usage:
#   capex-classify.sh classify --nature capitalizable|corriente|mixta \
#     --asset id,name,phase --justification "text" \
#     [--engagement CLIENT/ENGAGEMENT] [--split 70/30]
#   capex-classify.sh ledger-show --engagement CLIENT/ENGAGEMENT
#   capex-classify.sh ledger-verify --engagement CLIENT/ENGAGEMENT
#   capex-classify.sh --help
#
# The ledger is a hash-chained JSONL file:
#   engagements/{client}/{engagement}/capex-ledger.jsonl

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
RULES_FILE="${REPO_ROOT}/rules/capitalization.rules.yaml"

# ── Helpers ──────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
capex-classify.sh — SE-272 S1 CAPEX/OPEX classification

Usage:
  capex-classify.sh classify
    --nature capitalizable|corriente|mixta
    --asset id,name,phase
    --justification "text"
    [--engagement CLIENT/ENGAGEMENT]
    [--split PERCENT_CAPEX/PERCENT_OPEX]
    [--actor NAME]

  capex-classify.sh ledger-show
    --engagement CLIENT/ENGAGEMENT

  capex-classify.sh ledger-verify
    --engagement CLIENT/ENGAGEMENT

  capex-classify.sh ledger-status
    --engagement CLIENT/ENGAGEMENT

Classification validates against rules/capitalization.rules.yaml
Records confirmation as signed event in engagement ledger.
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

# ── Validate classification against rules ───────────────────────────

get_phase_from_rules() {
  local phase="$1"
  local result
  result="$(grep -A1 "  ${phase}:" "$RULES_FILE" | head -1 || true)"
  if [[ -z "$result" ]]; then
    echo "UNKNOWN"
  else
    echo "$result"
  fi
}

is_phase_capitalizable() {
  local phase="$1"
  if [[ ! -f "$RULES_FILE" ]]; then
    echo "WARNING: rules file not found at ${RULES_FILE}" >&2
    return 1
  fi
  local capitalizable
  capitalizable="$(grep -A10 "^  ${phase}:" "$RULES_FILE" | grep "capitalizable:" | grep -o "true\|false" | head -1 || echo "false")"
  if [[ "$capitalizable" == "true" ]]; then
    return 0
  fi
  return 1
}

validate_classification() {
  local nature="$1"
  local phase="$2"

  if [[ ! -f "$RULES_FILE" ]]; then
    echo "WARNING: ${RULES_FILE} not found, skipping rules validation" >&2
    return 0
  fi

  case "$nature" in
    capitalizable)
      if ! is_phase_capitalizable "$phase"; then
        echo "FAIL: phase '${phase}' is not capitalizable per rules/capitalization.rules.yaml" >&2
        return 1
      fi
      ;;
    corriente)
      if is_phase_capitalizable "$phase" 2>/dev/null; then
        echo "WARNING: phase '${phase}' is capitalizable, but nature is 'corriente'. Ensure intention." >&2
      fi
      ;;
    mixta)
      ;;
  esac
  return 0
}

# ── Ledger helpers ──────────────────────────────────────────────────

get_prev_hash() {
  local ledger_file="$1"
  if [[ ! -f "$ledger_file" ]] || [[ ! -s "$ledger_file" ]]; then
    echo "0000000000000000000000000000000000000000000000000000000000000000"
    return
  fi
  local last_hash
  last_hash="$(grep -o '"hash":"[^"]*"' "$ledger_file" | tail -1 | cut -d'"' -f4)"
  if [[ -z "$last_hash" ]]; then
    echo "0000000000000000000000000000000000000000000000000000000000000000"
  else
    echo "${last_hash#sha256:}"
  fi
}

# ── Subcommand: classify ────────────────────────────────────────────

cmd_classify() {
  local nature="" asset="" justification="" engagement="" split="" actor="${USER:-unknown}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --nature)       nature="$2";       shift 2 ;;
      --asset)        asset="$2";        shift 2 ;;
      --justification) justification="$2"; shift 2 ;;
      --engagement)   engagement="$2";   shift 2 ;;
      --split)        split="$2";        shift 2 ;;
      --actor)        actor="$2";        shift 2 ;;
      *) die "classify: unknown argument: $1" ;;
    esac
  done

  [[ -z "$nature"       ]] && die "classify: --nature is required (capitalizable|corriente|mixta)"
  [[ -z "$asset"        ]] && die "classify: --asset is required (id,name,phase)"
  [[ -z "$justification" ]] && die "classify: --justification is required"
  [[ -z "$engagement"   ]] && die "classify: --engagement is required (CLIENT/ENGAGEMENT)"

  case "$nature" in
    capitalizable|corriente|mixta) ;;
    *) die "classify: --nature must be capitalizable|corriente|mixta, got: ${nature}" ;;
  esac

  local asset_id asset_name asset_phase
  IFS=',' read -r asset_id asset_name asset_phase <<< "$asset"
  [[ -z "$asset_id"    ]] && die "classify: --asset format is id,name,phase"
  [[ -z "$asset_name"  ]] && die "classify: --asset format is id,name,phase"
  [[ -z "$asset_phase" ]] && die "classify: --asset format is id,name,phase"

  # Validate against rules
  if ! validate_classification "$nature" "$asset_phase"; then
    exit 1
  fi

  # Mixta requires split
  if [[ "$nature" == "mixta" && -z "$split" ]]; then
    die "classify: --split is required for mixta nature (e.g. --split 70/30)"
  fi

  if [[ -n "$split" ]]; then
    if ! [[ "$split" =~ ^[0-9]+/[0-9]+$ ]]; then
      die "classify: --split must be PERCENT_CAPEX/PERCENT_OPEX (e.g. 70/30)"
    fi
    local capex_pct="${split%%/*}"
    local opex_pct="${split##*/}"
    if [[ "$(( capex_pct + opex_pct ))" -ne 100 ]]; then
      die "classify: --split percentages must sum to 100, got ${capex_pct}+${opex_pct}=$(( capex_pct + opex_pct ))"
    fi
  fi

  # Resolve engagement paths
  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local eng_dir="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}"
  mkdir -p "$eng_dir"
  local ledger_file="${eng_dir}/capex-ledger.jsonl"

  local ts
  ts="$(timestamp_utc)"
  local prev_hash
  prev_hash="$(get_prev_hash "$ledger_file")"

  # Compose entry
  local chain_input="${ts}${nature}${asset_id}${asset_name}${asset_phase}${justification}${actor}${prev_hash}"
  local hash
  hash="sha256:$(sha256_str "$chain_input")"

  local split_field=""
  if [[ -n "$split" ]]; then
    split_field=",\"split\":\"${split}\""
  fi

  local entry
  entry="{\"ts\":\"${ts}\",\"nature\":\"${nature}\",\"asset_id\":\"${asset_id}\",\"asset_name\":\"${asset_name}\",\"asset_phase\":\"${asset_phase}\",\"justification\":\"${justification}\",\"actor\":\"${actor}\",\"split\":\"${split:-}\",\"prev_hash\":\"${prev_hash}\",\"hash\":\"${hash}\"}"

  cat <<JSONREE
{
  "ts": "${ts}",
  "nature": "${nature}",
  "asset_id": "${asset_id}",
  "asset_name": "${asset_name}",
  "asset_phase": "${asset_phase}",
  "justification": "${justification}",
  "actor": "${actor}",
  "split": "${split:-}",
  "prev_hash": "${prev_hash}",
  "hash": "${hash}"
}
JSONREE

  echo "$entry" >> "$ledger_file"
  echo "OK: classification recorded in ${ledger_file}"
  echo "    hash: ${hash}"
}

# ── Subcommand: ledger-show ─────────────────────────────────────────

cmd_ledger_show() {
  local engagement=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement) engagement="$2"; shift 2 ;;
      *) die "ledger-show: unknown argument: $1" ;;
    esac
  done

  [[ -z "$engagement" ]] && die "ledger-show: --engagement is required"

  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local ledger_file="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}/capex-ledger.jsonl"

  if [[ ! -f "$ledger_file" ]]; then
    echo "No ledger found at ${ledger_file}"
    exit 0
  fi

  echo "# CAPEX Ledger — Engagement: ${engagement}"
  echo ""
  printf "%-22s %-14s %-12s %-20s %s\n" "Timestamp" "Nature" "Asset ID" "Phase" "Hash"
  printf "%-22s %-14s %-12s %-20s %s\n" "---------" "------" "--------" "-----" "----"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local ts nature aid phase hash
    ts="$(echo "$line"    | grep -o '"ts":"[^"]*"'        | head -1 | cut -d'"' -f4)"
    nature="$(echo "$line" | grep -o '"nature":"[^"]*"'    | head -1 | cut -d'"' -f4)"
    aid="$(echo "$line"   | grep -o '"asset_id":"[^"]*"'  | head -1 | cut -d'"' -f4)"
    phase="$(echo "$line" | grep -o '"asset_phase":"[^"]*"' | head -1 | cut -d'"' -f4)"
    hash="$(echo "$line"  | grep -o '"hash":"[^"]*"'      | head -1 | cut -d'"' -f4)"
    printf "%-22s %-14s %-12s %-20s %s\n" "${ts}" "${nature}" "${aid}" "${phase}" "${hash:0:32}..."
  done < "$ledger_file"
}

# ── Subcommand: ledger-verify ────────────────────────────────────────

cmd_ledger_verify() {
  local engagement=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement) engagement="$2"; shift 2 ;;
      *) die "ledger-verify: unknown argument: $1" ;;
    esac
  done

  [[ -z "$engagement" ]] && die "ledger-verify: --engagement is required"

  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local ledger_file="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}/capex-ledger.jsonl"

  if [[ ! -f "$ledger_file" ]]; then
    echo "No ledger found at ${ledger_file}"
    exit 1
  fi

  local prev_hash="0000000000000000000000000000000000000000000000000000000000000000"
  local line_num=0
  local tampered=0
  local total=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    line_num=$(( line_num + 1 ))
    total=$(( total + 1 ))

    local ts nature aid aname phase justification actor split stored_prev stored_hash
    ts="$(echo "$line"            | grep -o '"ts":"[^"]*"'            | head -1 | cut -d'"' -f4)"
    nature="$(echo "$line"        | grep -o '"nature":"[^"]*"'        | head -1 | cut -d'"' -f4)"
    aid="$(echo "$line"          | grep -o '"asset_id":"[^"]*"'      | head -1 | cut -d'"' -f4)"
    aname="$(echo "$line"        | grep -o '"asset_name":"[^"]*"'    | head -1 | cut -d'"' -f4)"
    phase="$(echo "$line"        | grep -o '"asset_phase":"[^"]*"'   | head -1 | cut -d'"' -f4)"
    justification="$(echo "$line" | grep -o '"justification":"[^"]*"' | head -1 | cut -d'"' -f4)"
    actor="$(echo "$line"        | grep -o '"actor":"[^"]*"'         | head -1 | cut -d'"' -f4)"
    split="$(echo "$line"        | grep -o '"split":"[^"]*"'         | head -1 | cut -d'"' -f4)"
    stored_prev="$(echo "$line"   | grep -o '"prev_hash":"[^"]*"'    | head -1 | cut -d'"' -f4)"
    stored_hash="$(echo "$line"   | grep -o '"hash":"[^"]*"'         | head -1 | cut -d'"' -f4)"

    local chain_input="${ts}${nature}${aid}${aname}${phase}${justification}${actor}${prev_hash}"
    local expected_hash="sha256:$(sha256_str "$chain_input")"

    if [[ "${stored_prev}" != "${prev_hash}" ]]; then
      echo "TAMPERED: line ${line_num} — prev_hash mismatch"
      tampered=$(( tampered + 1 ))
    fi

    if [[ "${stored_hash}" != "${expected_hash}" ]]; then
      echo "TAMPERED: line ${line_num} — hash mismatch"
      tampered=$(( tampered + 1 ))
    fi

    prev_hash="${stored_hash#sha256:}"
  done < "$ledger_file"

  echo "Verified ${total} entries"
  if [[ "$tampered" -eq 0 ]]; then
    echo "CHAIN OK"
  else
    echo "CHAIN FAIL: ${tampered} violation(s)"
    exit 1
  fi
}

# ── Subcommand: ledger-status ────────────────────────────────────────

cmd_ledger_status() {
  local engagement=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --engagement) engagement="$2"; shift 2 ;;
      *) die "ledger-status: unknown argument: $1" ;;
    esac
  done

  [[ -z "$engagement" ]] && die "ledger-status: --engagement is required"

  local client_eng="${engagement%/*}"
  local eng_slug="${engagement#*/}"
  local ledger_file="${REPO_ROOT}/engagements/${client_eng}/${eng_slug}/capex-ledger.jsonl"

  if [[ ! -f "$ledger_file" ]]; then
    echo "No ledger found at ${ledger_file}"
    exit 0
  fi

  local count
  count="$(grep -c . "$ledger_file" 2>/dev/null || echo 0)"
  local last_hash
  last_hash="$(get_prev_hash "$ledger_file")"

  echo "Engagement: ${engagement}"
  echo "Entries:    ${count}"
  echo "Last hash:  sha256:${last_hash:0:32}..."
}

# ── Dispatch ─────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  usage
fi

subcmd="$1"
shift

case "$subcmd" in
  classify)        cmd_classify "$@" ;;
  ledger-show)     cmd_ledger_show "$@" ;;
  ledger-verify)   cmd_ledger_verify "$@" ;;
  ledger-status)   cmd_ledger_status "$@" ;;
  -h|--help)       usage ;;
  *) echo "ERROR: unknown subcommand: ${subcmd}" >&2
     echo "Run with --help for usage." >&2
     exit 2 ;;
esac
