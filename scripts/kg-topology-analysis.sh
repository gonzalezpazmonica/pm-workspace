#!/usr/bin/env bash
# kg-topology-analysis.sh — SE-248: wrapper for kg-topology-analysis.py
# Usage:
#   bash scripts/kg-topology-analysis.sh [--db <path>] [--input <json>] [--all] [--format md|json|both]
#   bash scripts/kg-topology-analysis.sh --help
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${SCRIPT_DIR}/kg-topology-analysis.py"
DEFAULT_DB="${HOME}/.savia/knowledge-graph.db"

show_usage() {
  cat <<USG
Usage: kg-topology-analysis.sh [OPTIONS]

SE-248: Forman-Ricci curvature + Leiden community detection
        on the pm-workspace knowledge graph.

Options:
  --db <path>          Path to knowledge-graph.db (default: ~/.savia/knowledge-graph.db)
  --input <json>       JSON export from knowledge-graph.sh --export-json
  --forman-ricci       Run Forman-Ricci analysis only
  --leiden             Run Leiden community detection only
  --spectral           Run spectral health (lambda2) only
  --all, -a            Run all analyses (default)
  --format <fmt>       Output format: json | md | both (default: both)
  --output-dir <dir>   Output directory (default: output/research)
  --help, -h           Show this help

Output files:
  output/research/kg-topology-YYYYMMDD.json
  output/research/kg-topology-YYYYMMDD.md

Examples:
  bash scripts/kg-topology-analysis.sh
  bash scripts/kg-topology-analysis.sh --db /custom/path/kg.db --format json
  bash scripts/kg-topology-analysis.sh --input /tmp/kg-export.json --leiden
USG
}

# ── --help early exit (before dependency gates) ─────────────────────────────

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_usage
  exit 0
fi

# ── Gate: python3 present ────────────────────────────────────────────────────

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found in PATH" >&2
  exit 3
fi

# ── Gate: script present ─────────────────────────────────────────────────────

if [[ ! -f "$PY" ]]; then
  echo "ERROR: $PY not found" >&2
  exit 3
fi

# ── Gate: networkx + numpy available ────────────────────────────────────────

if ! python3 -c "import networkx, numpy" 2>/dev/null; then
  echo "ERROR: required Python packages not found." >&2
  echo "Install: pip install networkx numpy" >&2
  exit 3
fi

# ── Parse args and pass through to Python ───────────────────────────────────

if [[ $# -eq 0 ]]; then
  # Default: use standard DB path
  if [[ -f "$DEFAULT_DB" ]]; then
    exec python3 "$PY" --db "$DEFAULT_DB" --all --format both
  else
    echo "ERROR: default DB not found: $DEFAULT_DB" >&2
    echo "Run: bash scripts/knowledge-graph.sh build first" >&2
    echo "Or: bash scripts/kg-topology-analysis.sh --input <json>" >&2
    exit 3
  fi
fi

# Pass all arguments directly to the Python script
exec python3 "$PY" "$@"
