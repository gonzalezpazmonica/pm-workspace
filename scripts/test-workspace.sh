#!/usr/bin/env bash
# test-workspace.sh — wrapper SE-253 Slice 7
# Delegates to test_workspace.py for data-heavy validation
# Original (860 líneas, 35 usos de jq) migrado a scripts/test_workspace.py
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/test_workspace.py" "$@"
