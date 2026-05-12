#!/usr/bin/env bash
# context-update.sh — wrapper for /context-update pipeline
# Rule #26: bash = thin wrapper; Python owns logic.
# SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 Slice 6.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/savia-env.sh" 2>/dev/null || true

WORKSPACE="${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}}}"

PYTHON="${PYTHON:-python3}"
ENTRYPOINT="${SCRIPT_DIR}/context_update_main.py"

if [[ ! -f "$ENTRYPOINT" ]]; then
  echo "ERROR: context_update_main.py not found at $ENTRYPOINT" >&2
  exit 1
fi

exec "$PYTHON" "$ENTRYPOINT" "$@"
