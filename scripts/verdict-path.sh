#!/usr/bin/env bash
# verdict-path.sh — SE-367: wrapper de verdict-path.py (attach/expand/
# show/validate/--validate). La logica vive en Python; esto es la puerta
# bash para courts y gates. CRIT-001: todo local.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/verdict-path.py" "$@"
