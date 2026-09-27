#!/usr/bin/env bash
set -uo pipefail
# runs-cost-capture-hook.sh — SubagentStop (SE-405 Slice 1). Delegates to
# scripts/runs-cost-capture.sh; no-op unless SAVIA_RUN_ID is set. Never blocks.
# opencode-binding: NOT_EXPOSED — OpenCode has no SubagentStop event; cost is recorded with `savia-runs.sh cost` (SE-405 §portability).
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
bash "$ROOT/scripts/runs-cost-capture.sh" 2>/dev/null || true
exit 0
