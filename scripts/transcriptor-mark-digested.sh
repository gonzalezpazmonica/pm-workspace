#!/usr/bin/env bash
# transcriptor-mark-digested.sh — marcar una reunion como digerida
# Usage: bash scripts/transcriptor-mark-digested.sh <carpeta>
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSCRIPTOR_DIR="${SAVIA_TRANSCRIPTOR_DIR:-$HOME/.savia/transcriptor}"
MEETINGS_DIR="$TRANSCRIPTOR_DIR/reuniones"

SESSION="${1:-}"
if [[ -z "$SESSION" ]]; then
  echo "Usage: transcriptor-mark-digested.sh <carpeta>" >&2
  exit 1
fi

# Resolver: si es un nombre (YYYY-MM-DD-HH-MM) o una ruta
if [[ "$SESSION" == */* ]]; then
  SESSION_PATH="$SESSION"
else
  SESSION_PATH="$MEETINGS_DIR/$SESSION"
fi

META="$SESSION_PATH/meta.json"
if [[ ! -f "$META" ]]; then
  echo "ERROR: no se encuentra $META" >&2
  exit 1
fi

python3 -c "
import json
p = '$META'
d = json.load(open(p))
d['digested'] = True
json.dump(d, open(p, 'w'), indent=2, ensure_ascii=False)
"
echo "Marcada como digerida: $(basename "$SESSION_PATH")"
