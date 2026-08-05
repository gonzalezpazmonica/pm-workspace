#!/usr/bin/env bash
# launch-savia-transcriptor.sh — arranca Savia Transcriptor con su venv
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PY="$SCRIPT_DIR/.venv/bin/python"
MAIN="$SCRIPT_DIR/src-pyloid/main.py"

if [[ ! -x "$VENV_PY" ]]; then
  echo "ERROR: venv no encontrado en $SCRIPT_DIR/.venv" >&2
  echo "Ejecuta: python3 -m venv .venv && .venv/bin/pip install -e ." >&2
  exit 1
fi

cd "$SCRIPT_DIR"
exec "$VENV_PY" "$MAIN" "$@"
