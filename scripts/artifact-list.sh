#!/usr/bin/env bash
# artifact-list.sh — Lista artifacts de un run. ≤15 líneas. Rule #26.
# Uso: ./scripts/artifact-list.sh [--artifacts-dir DIR] [--run-id ID] [--mime MIME]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTIFACTS_DIR="${SAVIA_ARTIFACTS_DIR:-output/artifacts}"
PASSTHROUGH_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifacts-dir) ARTIFACTS_DIR="$2"; shift 2 ;;
    *) PASSTHROUGH_ARGS+=("$1"); shift ;;
  esac
done
PYTHONPATH="${SCRIPT_DIR}/.." python3 -m scripts.lib.artifacts.cli \
  --artifacts-dir "$ARTIFACTS_DIR" list "${PASSTHROUGH_ARGS[@]+"${PASSTHROUGH_ARGS[@]}"}"
