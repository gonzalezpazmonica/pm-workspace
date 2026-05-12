#!/usr/bin/env bash
# savia-lock.sh — Regenera savia.lock desde savia.manifest.yaml.
# SPEC-SAVIA-MANIFEST Slice 3 §2.4. Rule #26: lógica en Python.
# Uso: bash scripts/savia-lock.sh [--manifest PATH] [--workspace PATH] [--out PATH]
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$REPO_ROOT/scripts/lib:${PYTHONPATH:-}"
exec python3 -m savia_manifest.cli lock "$@"
