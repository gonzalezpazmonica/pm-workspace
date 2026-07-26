#!/usr/bin/env bash
# corporate-ledger-verify.sh — SE-271 S2
# Verifies hash-chain integrity of the corporate adoption ledger.
# Reports entries, declinations, versions.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LEDGER="${LEDGER:-$REPO_ROOT/data/corporate/adoption-ledger.jsonl}"
MONOTONICITY_LEDGER="${MONOTONICITY_LEDGER:-$REPO_ROOT/data/corporate/monotonicity-ledger.jsonl}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--ledger <path>] [--monotonicity-ledger <path>]

Verifies hash-chain integrity of the corporate ledger(s).
Reports entries, declinations, and versions.

Options:
  --ledger <path>              Path to adoption ledger (default: data/corporate/adoption-ledger.jsonl)
  --monotonicity-ledger <path> Path to monotonicity ledger (default: data/corporate/monotonicity-ledger.jsonl)

Exit codes:
  0   Ledger integrity verified.
  1   Hash chain broken or ledger tampered.
EOF
  exit 2
}

# ── helpers ──────────────────────────────────────────────────────────────

verify_single_ledger() {
  local ledger_path="$1"
  local ledger_name="$2"

  echo "--- $ledger_name ---"
  echo "Path: $ledger_path"
  echo ""

  if [[ ! -f "$ledger_path" ]]; then
    echo "  Ledger file not found. No entries to verify."
    echo ""
    return 0
  fi

  if [[ ! -s "$ledger_path" ]]; then
    echo "  Ledger is empty. No entries."
    echo ""
    return 0
  fi

  # Verify hash chain
  local prev_hash="genesis"
  local line_num=0
  local chain_ok=true
  local total_entries=0
  local adopted=0
  local declined=0
  local rejected=0
  local integrity_errors=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))
    total_entries=$((total_entries + 1))

    # Check valid JSON
    if ! echo "$line" | python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null; then
      echo "  LINE $line_num: INVALID — not valid JSON"
      integrity_errors=$((integrity_errors + 1))
      continue
    fi

    # Extract prev_ledger_hash
    local stored_prev
    stored_prev=$(echo "$line" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('prev_ledger_hash','MISSING'))" 2>/dev/null)

    if [[ "$stored_prev" != "$prev_hash" ]]; then
      echo "  LINE $line_num: CHAIN BREAK — stored=$stored_prev, computed=$prev_hash"
      chain_ok=false
      integrity_errors=$((integrity_errors + 1))
    fi

    # Compute this line's hash for next iteration
    prev_hash=$(echo "$line" | sha256sum | awk '{print $1}')

    # Count actions
    local action
    action=$(echo "$line" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('action','unknown'))" 2>/dev/null)
    case "$action" in
      adopted) adopted=$((adopted + 1)) ;;
      declined) declined=$((declined + 1)) ;;
      rejected) rejected=$((rejected + 1)) ;;
    esac
  done < "$ledger_path"

  echo "  Total entries: $total_entries"
  echo "  Adopted: $adopted"
  echo "  Declined: $declined"
  echo "  Rejected: $rejected"
  echo ""

  if [[ "$chain_ok" == true && "$integrity_errors" -eq 0 ]]; then
    echo "  Chain integrity: OK"
    echo ""
    return 0
  else
    echo "  Chain integrity: BROKEN ($integrity_errors error(s))"
    echo ""
    return 1
  fi
}

# ── main ──────────────────────────────────────────────────────────────────

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ledger)
        LEDGER="$2"
        shift 2
        ;;
      --monotonicity-ledger)
        MONOTONICITY_LEDGER="$2"
        shift 2
        ;;
      -h|--help)
        usage
        ;;
      *)
        echo "ERROR: Unknown option: $1" >&2
        usage
        ;;
    esac
  done

  echo "=== Corporate Ledger Verification ==="
  echo ""

  local overall_ok=true

  verify_single_ledger "$LEDGER" "Adoption Ledger" || overall_ok=false
  verify_single_ledger "$MONOTONICITY_LEDGER" "Monotonicity Gate Ledger" || overall_ok=false

  if [[ "$overall_ok" == true ]]; then
    echo "OVERALL: PASS — all ledgers verified."
    exit 0
  else
    echo "OVERALL: FAIL — one or more ledgers have integrity issues."
    exit 1
  fi
}

main "$@"
