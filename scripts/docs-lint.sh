#!/bin/bash
set -uo pipefail
# docs-lint.sh — SE-259 Slice 1. Bash wrapper for docs-lint.py
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/docs-lint.py" "$@"
