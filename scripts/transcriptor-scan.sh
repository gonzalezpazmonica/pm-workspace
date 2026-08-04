#!/usr/bin/env bash
# transcriptor-scan.sh — listar reuniones sin digerir de Savia Transcriptor
# Usage: bash scripts/transcriptor-scan.sh [--all]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSCRIPTOR_DIR="${SAVIA_TRANSCRIPTOR_DIR:-$HOME/.savia/transcriptor}"
MEETINGS_DIR="$TRANSCRIPTOR_DIR/reuniones"
MODE="${1:-undigested}"

if [[ ! -d "$MEETINGS_DIR" ]]; then
  echo "No hay reuniones todavia en $MEETINGS_DIR"
  exit 0
fi

for session in "$MEETINGS_DIR"/*/; do
  [[ -d "$session" ]] || continue
  name="$(basename "$session")"
  meta="$session/meta.json"
  digested="false"
  if [[ -f "$meta" ]]; then
    digested=$(python3 -c "import json;print(json.load(open('$meta')).get('digested', False))" 2>/dev/null || echo "false")
  fi
  if [[ "$MODE" == "--all" ]]; then
    echo "$name digested=$digested"
  elif [[ "$digested" != "True" ]]; then
    echo "$name"
  fi
done
