#!/usr/bin/env bash
# router-check.sh — wrapper SE-346: llm-router --check (read-only) con el python del venv.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PY="$(command -v "$HOME/.savia/venv/bin/python" 2>/dev/null || echo "$HOME/.savia/venv/bin/python")"
if [[ ! -x "$PY" ]]; then
  PY="$(command -v python3 || true)"
fi
export WORKSPACE_DIR="${WORKSPACE_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
exec "$PY" "$SCRIPT_DIR/llm-router.py" --check "$@"
