#!/usr/bin/env bash
# context-guard-monitor.sh — OpenCode hook: fires before each model call.
# Checks context_guard config; if enabled, delegates to python CLI.
# Rule #26: Bash as thin wrapper only. Spec §2.2 / SPEC-127.
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${HOOK_DIR}/../.." && pwd)"

AGENT_FILE="${OPENCODE_AGENT_FILE:-}"
[ -z "${AGENT_FILE}" ] && exit 0

exec python3 -m scripts.lib.context_guard.cli \
    --base-dir "${WORKSPACE_DIR}/output/context-guard" \
    list "${OPENCODE_RUN_ID:-unknown}" 2>/dev/null || true
