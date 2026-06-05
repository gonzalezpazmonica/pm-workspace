#!/usr/bin/env bash
# code-twin-extract.sh — SPEC-190 Slice 7
# Bash wrapper for code-twin-extract.py (AST-light extractor).
#
# Usage:
#   bash scripts/code-twin-extract.sh --lang <typescript|csharp|python>
#                                      --src <source_dir>
#                                      --out <output_dir>
#                                      [--arch <architecture_md>]
#                                      [--project <slug>]
#
# Exit codes:
#   0 — extraction successful
#   1 — no classes found
#   2 — argument / IO error
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/code-twin-extract.py"

if [[ ! -f "${PYTHON_SCRIPT}" ]]; then
  echo "ERROR: engine not found: ${PYTHON_SCRIPT}" >&2
  exit 2
fi

exec python3 "${PYTHON_SCRIPT}" "$@"
