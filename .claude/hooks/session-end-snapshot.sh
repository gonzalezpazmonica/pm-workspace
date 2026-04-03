#!/usr/bin/env bash
# session-end-snapshot.sh — Save context snapshot at session end
# Hook: Stop event. Runs when Claude session ends.
# ─────────────────────────────────────────────────────────────────
set -uo pipefail

ERR_LOG="$HOME/.savia/hook-errors.log"
trap 'echo "[$(date +%H:%M:%S)] session-end-snapshot: $BASH_COMMAND failed (line $LINENO)" >> "$ERR_LOG" 2>/dev/null' ERR

cat /dev/stdin > /dev/null 2>&1 || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."

SNAPSHOT_SCRIPT=""
for spath in "$ROOT/scripts/context-snapshot.sh" "./scripts/context-snapshot.sh"; do
  if [ -x "$spath" ]; then
    SNAPSHOT_SCRIPT="$spath"
    break
  fi
done

if [ -n "$SNAPSHOT_SCRIPT" ]; then
  echo '' | bash "$SNAPSHOT_SCRIPT" save > /dev/null 2>&1 || true
fi
