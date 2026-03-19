#!/usr/bin/env bash
# criticality.sh — Dispatcher for criticality operations
# Usage: criticality.sh {assess|dashboard|rebalance} [args]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/criticality-engine.sh"

case "${1:-help}" in
  assess)    shift; do_assess "$@" ;;
  dashboard) shift; do_dashboard "$@" ;;
  rebalance) shift; do_rebalance "$@" ;;
  *)
    echo "Usage: criticality.sh {assess|dashboard|rebalance} [args]"
    echo "  assess <item-id> [--project name]   Score a single item"
    echo "  dashboard [--project name]          Cross-project P0-P3 view"
    echo "  rebalance [--project name] [--dry-run]  Redistribute workload"
    ;;
esac
