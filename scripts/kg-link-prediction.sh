#!/usr/bin/env bash
# kg-link-prediction.sh — SE-249: wrapper for kg-link-prediction.py
# Usage:
#   bash scripts/kg-link-prediction.sh [--db <path>] [--input <json>] [--epochs 200] [--top-n 20]
#   bash scripts/kg-link-prediction.sh --help
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${SCRIPT_DIR}/kg-link-prediction.py"
DEFAULT_DB="${HOME}/.savia/knowledge-graph.db"
MIN_TRIPLES=50

show_usage() {
  cat <<USG
Usage: kg-link-prediction.sh [OPTIONS]

SE-249: RotatE link prediction for implicit dependencies in the pm-workspace KG.

Options:
  --db <path>          Path to knowledge-graph.db (default: ~/.savia/knowledge-graph.db)
  --input <json>       JSON export from knowledge-graph.sh
  --epochs <n>         Training epochs (default: 200)
  --dim <n>            Embedding dimension (default: 50)
  --top-n <n>          Top N predictions (default: 20)
  --format <fmt>       Output: json | md | both (default: both)
  --output-dir <dir>   Output directory (default: output/research)
  --help, -h           Show this help

WARNING: If KG has hub-and-spoke structure (bottleneck_ratio=1.0), MRR will be low.
Run kg-topology-analysis.sh first to assess KG structure.

Output files:
  output/research/kg-missing-links-YYYYMMDD.json
  output/research/kg-missing-links-YYYYMMDD.md
USG
}

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found" >&2; exit 3
fi

if [[ ! -f "$PY" ]]; then
  echo "ERROR: $PY not found" >&2; exit 3
fi

if ! python3 -c "import numpy" 2>/dev/null; then
  echo "ERROR: numpy not found. Install: pip install numpy" >&2; exit 3
fi

if [[ $# -eq 0 ]]; then
  if [[ -f "$DEFAULT_DB" ]]; then
    exec python3 "$PY" --db "$DEFAULT_DB" --format both
  else
    echo "ERROR: default DB not found: $DEFAULT_DB" >&2
    echo "Run: bash scripts/knowledge-graph.sh build" >&2
    exit 3
  fi
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_usage; exit 0
fi

exec python3 "$PY" "$@"
