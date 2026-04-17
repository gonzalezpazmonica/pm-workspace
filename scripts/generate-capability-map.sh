#!/usr/bin/env bash
# ── generate-capability-map.sh — Thin wrapper around the Python generator.
#
# The original Bash implementation spawned thousands of sed/grep sub-processes
# per file which took > 1 hour on Windows (MSYS/Git Bash fork is slow).
# The heavy lifting now lives in `generate-capability-map.py` which finishes
# in ~2 seconds. This wrapper keeps the old invocation contract so any hook
# that still calls the `.sh` keeps working.
#
# Usage:  generate-capability-map.sh [repo_root]
# Output: writes to  <repo_root>/.scm/
set -uo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PYTHON_SCRIPT="$(dirname "$0")/generate-capability-map.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "generate-capability-map: python3 not found in PATH" >&2
  exit 1
fi

exec python3 "$PYTHON_SCRIPT" "$REPO_ROOT"
