#!/usr/bin/env bash
# Native markdownlint wrapper — no npm dependency.
# Usage: bash scripts/markdownlint.sh [--fix] [--config FILE] FILE...
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 -m scripts.markdownlint "$@"
