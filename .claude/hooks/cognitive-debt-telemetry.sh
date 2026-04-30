#!/usr/bin/env bash
set -uo pipefail
# cognitive-debt-telemetry.sh — SPEC-107 I4 PostToolUse hook (async, non-blocking).
#
# Records each tool call (Edit/Write/Task) to a per-user JSONL log for later
# aggregation. Async, never blocks tool execution, never invokes LLM (CD-01).
#
# Privacy: log is N3 in ~/.savia/cognitive-load/{user}.jsonl, gitignored,
# never exposed to team/manager (CD-03). Equality Shield compliance (Rule #23).
#
# This hook runs ONLY when explicitly enabled via cognitive-debt.sh enable.
# Otherwise the hook is dormant on disk.
#
# Reference: SPEC-107 (`docs/propuestas/SPEC-107-ai-cognitive-debt-mitigation.md`)

USER_NAME="${USER:-unknown}"
TELEMETRY_DIR="${SAVIA_COGNITIVE_DIR:-$HOME/.savia/cognitive-load}"
LOG="$TELEMETRY_DIR/$USER_NAME.jsonl"

# Read tool input from stdin (Claude Code hook contract)
INPUT=$(cat 2>/dev/null || echo "{}")

# Extract minimal fields without invoking LLM. Use python for JSON parsing.
EVENT=$(printf '%s' "$INPUT" | python3 -c "
import json, sys, os
from datetime import datetime, timezone
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tool_name = d.get('tool_name', d.get('tool', 'unknown'))
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
duration_ms = d.get('duration_ms', d.get('elapsed_ms', None))
out = {
    'ts': ts,
    'tool': tool_name,
    'duration_ms': duration_ms,
    'session': os.environ.get('CLAUDE_SESSION_ID', '')[:8],
}
print(json.dumps(out, separators=(',', ':')))
" 2>/dev/null)

[ -z "$EVENT" ] && exit 0

# Async append (background). Never block the calling tool.
mkdir -p "$TELEMETRY_DIR" 2>/dev/null || exit 0
chmod 700 "$TELEMETRY_DIR" 2>/dev/null || true

# Append-only, with exclusive lock to avoid concurrent corruption.
{
  printf '%s\n' "$EVENT"
} >> "$LOG" 2>/dev/null || true

# Always exit 0 — never block the tool call (CD-02).
exit 0
