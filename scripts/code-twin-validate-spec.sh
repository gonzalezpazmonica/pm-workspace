#!/usr/bin/env bash
# code-twin-validate-spec.sh — SPEC-190 Slice 6
# Bash wrapper for code-twin-validate-spec.py.
#
# Usage:
#   bash scripts/code-twin-validate-spec.sh <spec_md> <code_twin_dir>
#
# Exit codes:
#   0 — feasibility_score >= 70
#   1 — feasibility_score < 70
#   2 — engine / argument error
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/code-twin-validate-spec.py"

if [[ ! -f "${PYTHON_SCRIPT}" ]]; then
  echo "ERROR: engine not found: ${PYTHON_SCRIPT}" >&2
  exit 2
fi

exec python3 "${PYTHON_SCRIPT}" "$@"
