#!/usr/bin/env bash
# context-opt-gate.sh — PreToolUse hook for CLAUDE.md writes
# SPEC-CONTEXT-OPT-GATE section 5
# Profile tier: context
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"

# Opt-out (default: enabled in dry-run until prereqs met)
[[ "${SAVIA_CONTEXT_OPT_ENABLED:-true}" == "false" ]] && exit 0

# Delegate to Python gate. Stdin (tool_input JSON) passes through.
exec python3 "$SAVIA_WORKSPACE_DIR/scripts/context-opt-gate.py"
