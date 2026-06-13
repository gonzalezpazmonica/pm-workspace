#!/usr/bin/env bash
# context-greedy-budget.sh — SPEC-189: Greedy context budget selection.
#
# Wrapper around scripts/context-greedy-budget.py. Selects the most relevant
# subgraph from a context graph (.acm, knowledge-graph DB, JSONL) within a
# token budget. Pattern: scoring (PageRank+TF-IDF+code-boost) + greedy budget
# + neighbor decay. Stdlib-only Python; no external deps required.
#
# Usage:
#   bash scripts/context-greedy-budget.sh <input> <query> [options]
#
# Examples:
#   bash scripts/context-greedy-budget.sh \
#     projects/savia-mobile-android/.agent-maps/INDEX.acm "chat" --budget 1000
#
#   bash scripts/context-greedy-budget.sh \
#     ~/.savia/knowledge-graph.db "SE-189" --budget 4000 --format json
#
# Options forwarded to the Python script. See: python3 scripts/context-greedy-budget.py --help

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/context-greedy-budget.py"

if [[ ! -f "$PY" ]]; then
  echo "ERROR: $PY not found" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  python3 "$PY" --help
  exit 0
fi

exec python3 "$PY" "$@"
