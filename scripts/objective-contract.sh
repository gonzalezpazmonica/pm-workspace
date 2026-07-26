#!/usr/bin/env bash
set -uo pipefail
# objective-contract.sh — SE-273 S7: Objetivo delegado con antagonista obligatorio
# Usage: bash scripts/objective-contract.sh {check|create|verify} [args...]
# Master switch: SAVIA_OBJECTIVE_CONTRACT=off

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CONTRACTS_DIR="${ROOT}/output/objective-contracts"
ACTION="${1:-}"; FILE="${2:-}"; EXTRA="${3:-}"
[[ "${SAVIA_OBJECTIVE_CONTRACT:-on}" == "off" ]] && exit 0
mkdir -p "$CONTRACTS_DIR"

do_check() {
  [[ ! -f "$FILE" ]] && echo "ERROR: not found: $FILE" >&2 && exit 2
  if ! grep -qE '^(meta|goal):' "$FILE" 2>/dev/null; then
    echo "REJECTED: no meta/goal declared" >&2; exit 1
  fi
  if ! grep -q 'antagonists:' "$FILE" 2>/dev/null; then
    echo "REJECTED: no antagonists section — every objective needs at least one declared antagonist" >&2
    echo "Default antagonists always apply: safety, confidentiality, ethics, reversibility" >&2
    exit 1
  fi
  echo "VALID: contract has goal and antagonists"
}

do_create() {
  local meta="$1"; shift
  [[ $# -eq 0 ]] && echo "REJECTED: objective without antagonist. Specify what must NOT degrade." >&2 && exit 1
  local id="obj-$(date +%Y%m%d-%H%M%S)"
  local cf="$CONTRACTS_DIR/${id}.yaml"
  cat > "$cf" <<YAML
meta: "$meta"
antagonists:
YAML
  for a in "$@"; do echo "  - \"$a\"" >> "$cf"; done
  echo "  - \"safety: no degradar la seguridad del sistema\"" >> "$cf"
  echo "  - \"confidentiality: no degradar la confidencialidad (CRIT-026)\"" >> "$cf"
  echo "  - \"ethics: no degradar el suelo etico (CRIT-027)\"" >> "$cf"
  echo "  - \"reversibility: no degradar la capacidad de revertir cambios\"" >> "$cf"
  cat >> "$cf" <<YAML
limits: {max_minutes: 30, max_tokens: 50000}
stop_condition: "antagonist_degraded OR goal_achieved OR timeout"
self_modification: forbidden
YAML
  echo "$cf"
}

do_verify() {
  [[ ! -f "$FILE" ]] && echo "ERROR: not found" >&2 && exit 2
  [[ ! -f "$EXTRA" ]] && exit 0
  if grep -q "self_modif" "$EXTRA" 2>/dev/null; then
    echo "CRITICAL: attempted self-modification (CRIT-031)" >&2; exit 1
  fi
  if grep -qE "degraded.*true" "$EXTRA" 2>/dev/null; then
    echo "BLOCKED: antagonist degraded" >&2; exit 1
  fi
  echo "OK"; exit 0
}

case "$ACTION" in
  check) do_check ;;
  create) shift 2 2>/dev/null; do_create "$FILE" "$@" ;;
  verify) do_verify ;;
  *) echo "Usage: $0 {check|create|verify} [args...]" >&2; exit 2 ;;
esac
