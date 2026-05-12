#!/usr/bin/env bash
# savia-doc.sh — wrapper for `python3 -m structured_doc`
# Rule #26: bash only invokes; Python owns the logic.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [[ -f "${REPO_ROOT}/.venv/bin/activate" ]]; then
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/.venv/bin/activate"
fi
cd "${REPO_ROOT}"
PYTHONPATH="${REPO_ROOT}/scripts/lib" exec python3 -m structured_doc "$@"
