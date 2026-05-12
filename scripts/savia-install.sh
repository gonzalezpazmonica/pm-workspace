#!/usr/bin/env bash
# savia-install.sh — Resolve and install a Savia pack into the workspace.
# SPEC-SAVIA-MANIFEST Slice 2. Rule #26: Python handles logic, bash orchestrates.
# Usage: bash scripts/savia-install.sh <source> [--workspace PATH] [--hash SHA256]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$REPO_ROOT/scripts/lib"

export PYTHONPATH="$LIB_DIR:${PYTHONPATH:-}"

exec python3 -m savia_manifest.cli install "$@"
