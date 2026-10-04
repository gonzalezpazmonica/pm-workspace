#!/usr/bin/env bash
# criticality.sh — Dispatcher for criticality operations
# Usage: criticality.sh {assess|dashboard|rebalance} [args]
# Exit codes: 0 ok · 1 not found · 2 usage error
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/criticality-engine.sh"

usage() {
  echo "Usage: criticality.sh {assess|dashboard|rebalance} [args]"
  echo "  assess <item-id> [--project name]   Score a single item"
  echo "  dashboard [--project name]          Cross-project P0-P3 view"
  echo "  rebalance [--project name] [--dry-run]  Redistribute workload"
}

case "${1:-help}" in
  assess)    shift; do_assess "$@" ;;
  dashboard) shift; do_dashboard "$@" ;;
  rebalance) shift; do_rebalance "$@" ;;
  help|-h|--help) usage ;;
  *) echo "ERROR: unknown command: $1" >&2; usage >&2; exit 2 ;;
esac
