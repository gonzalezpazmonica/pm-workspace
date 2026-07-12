#!/usr/bin/env bash
# memory-consolidate.sh — wrapper for memory-consolidate.py
set -uo pipefail
exec python3 "$(dirname "$0")/memory-consolidate.py" "$@"
