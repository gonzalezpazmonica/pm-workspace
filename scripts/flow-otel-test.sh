#!/usr/bin/env bash
# flow-otel-test.sh — Wrapper bash para /flow-otel-test (≤20 líneas efectivas).
# Invoca otel_test.py con el venv del workspace.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_PYTHON="$WORKSPACE_ROOT/.venv/bin/python3"
PYTHON3="${VENV_PYTHON:-python3}"
[[ -x "$VENV_PYTHON" ]] && PYTHON3="$VENV_PYTHON"

if ! [[ -x "$PYTHON3" ]] && ! command -v python3 &>/dev/null; then
  echo "python3 no encontrado. Instala Python 3.10+ para usar OTel." >&2
  exit 1
fi

exec "$PYTHON3" "$SCRIPT_DIR/lib/otel_test.py"
