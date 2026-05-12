#!/usr/bin/env bash
# flow-otel-exporter.sh — Wrapper bash para el exporter OTel (≤20 líneas efectivas).
# Conforme a Rule #26: bash solo como involtorio. Toda la lógica en Python.
# Invocado al final de /flow-run si SAVIA_OTEL_ENABLED=true.
set -euo pipefail

SAVIA_OTEL_ENABLED="${SAVIA_OTEL_ENABLED:-}"
TRACE_FILE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ "$SAVIA_OTEL_ENABLED" != "true" ]] && exit 0

if [[ -z "$TRACE_FILE" ]]; then
  echo "Usage: $0 <trace.jsonl>" >&2
  exit 1
fi

# Usar python3 del .venv del workspace si existe, o el del sistema
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_PYTHON="$WORKSPACE_ROOT/.venv/bin/python3"
PYTHON3="${VENV_PYTHON:-python3}"
[[ -x "$VENV_PYTHON" ]] && PYTHON3="$VENV_PYTHON"

if ! command -v "$PYTHON3" &>/dev/null && ! [[ -x "$PYTHON3" ]]; then
  echo "⚠ python3 no encontrado. OTel export desactivado." >&2
  exit 0
fi

exec "$PYTHON3" "$SCRIPT_DIR/lib/otel_exporter.py" --trace-file "$TRACE_FILE"
