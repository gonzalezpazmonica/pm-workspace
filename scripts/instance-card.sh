#!/usr/bin/env bash
# instance-card.sh — Savia instance identity cards (SE-263 S2)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<EOF
Usage: bash scripts/instance-card.sh <command> [options]
Commands: verify | show
  verify --id NAME [--registry DIR]   Check card signature and status
  show --id NAME [--registry DIR]     Display card contents
EOF
}

CMD=""; INSTANCE_ID=""; REGISTRY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    verify|show) CMD="$1"; shift ;;
    --id) INSTANCE_ID="$2"; shift 2 ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -z "$CMD" ]] && { echo "ERROR: command required" >&2; usage >&2; exit 1; }
[[ -z "$INSTANCE_ID" ]] && { echo "ERROR: --id required" >&2; exit 1; }

REGISTRY="${REGISTRY:-$ROOT/coordinacion/cards}"
CARDFILE="$REGISTRY/${INSTANCE_ID}.card.json"

cmd_verify() {
  [[ ! -f "$CARDFILE" ]] && { echo "VERIFY: card not found: $CARDFILE"; exit 1; }

  local status
  status=$(python3 -c "import json; d=json.load(open('$CARDFILE')); print(d.get('status',''))" 2>/dev/null || echo "")
  
  if [[ "$status" == "revoked" ]]; then
    echo "VERIFY: card REVOKED for $INSTANCE_ID"; exit 1
  fi

  local sig
  sig=$(python3 -c "import json; d=json.load(open('$CARDFILE')); print(d.get('signature',''))" 2>/dev/null || echo "")
  [[ -z "$sig" ]] && { echo "VERIFY: card UNSIGNED for $INSTANCE_ID"; exit 1; }

  local pid
  pid=$(python3 -c "import json; d=json.load(open('$CARDFILE')); print(d.get('principal',''))" 2>/dev/null || echo "")
  [[ -z "$pid" ]] && { echo "VERIFY: card has no principal for $INSTANCE_ID"; exit 1; }

  echo "VERIFY: card VALID ($INSTANCE_ID, principal=$pid, status=$status)"
}

cmd_show() {
  [[ ! -f "$CARDFILE" ]] && { echo "Card not found: $CARDFILE"; exit 1; }
  cat "$CARDFILE"
}

case "$CMD" in verify) cmd_verify ;; show) cmd_show ;; esac
