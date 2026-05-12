#!/usr/bin/env bash
# savia-sync.sh — Verifica y sincroniza workspace contra savia.lock.
# SPEC-SAVIA-MANIFEST Slice 3 §2.4. Rule #26: lógica en Python.
# Uso: bash scripts/savia-sync.sh [--lock PATH] [--workspace PATH] [--force]
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$REPO_ROOT/scripts/lib:${PYTHONPATH:-}"
exec python3 -m savia_manifest.cli sync "$@"
