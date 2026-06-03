#!/usr/bin/env bash
# knowledge-graph.sh — SE-162: Shell wrapper for knowledge-graph.py
#
# Usage:
#   bash scripts/knowledge-graph.sh build
#   bash scripts/knowledge-graph.sh query "SE-162"
#   bash scripts/knowledge-graph.sh impact "pm-workspace" [--depth N]
#   bash scripts/knowledge-graph.sh status
#   bash scripts/knowledge-graph.sh entities [--type TYPE]
#
# DB path: $KG_DB (default: ~/.savia/knowledge-graph.db)
# Requires: python3 (stdlib only, no pip deps)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/knowledge-graph.py"

if [[ ! -f "$PY" ]]; then
  echo "ERROR: $PY not found" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  python3 "$PY" --help
  exit 0
fi

exec python3 "$PY" "$@"
