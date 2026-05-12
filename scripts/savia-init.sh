#!/usr/bin/env bash
# savia-init.sh — Generate savia.manifest.yaml for the current workspace.
# SPEC-SAVIA-MANIFEST Slice 1. Rule #26: Python handles logic, bash orchestrates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"

export PYTHONPATH="$LIB_DIR:${PYTHONPATH:-}"

exec python3 -m savia_manifest.cli init "$@"
