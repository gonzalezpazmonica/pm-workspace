#!/bin/bash
set -uo pipefail
# session-end-memory.sh — Extract valuable context before session ends (SPEC-013)
# Hook: SessionEnd | Timeout: 1.5s (SessionEnd default)
# Extracts corrections, decisions, and discoveries to auto-memory.

# Drain stdin (hook protocol)
cat > /dev/null 2>/dev/null || true

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

# SessionEnd hooks have 1.5s timeout — keep it fast
# Just log the event; actual extraction happens in session-end-snapshot.sh
MEMORY_DIR="$HOME/.claude/projects/-home-monica-claude/memory"
SESSION_LOG="$HOME/.savia/session-end.log"
mkdir -p "$(dirname "$SESSION_LOG")"

echo "$(date -Iseconds) | session-end | memory-extraction-triggered" >> "$SESSION_LOG" 2>/dev/null

exit 0
