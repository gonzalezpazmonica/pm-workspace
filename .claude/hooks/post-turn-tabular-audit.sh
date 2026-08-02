#!/usr/bin/env bash
set -euo pipefail
# post-turn-tabular-audit.sh — Capa 4: self-audit after each turn
# Checks if tabular tools were used when tabular data was present

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDITOR="$SCRIPT_DIR/../../scripts/tabular-self-audit.sh"

if [[ -x "$AUDITOR" ]]; then
  # Run audit on the current session log if available
  SESSION_LOG="${SAVIA_SESSION_LOG:-}"
  if [[ -n "$SESSION_LOG" && -f "$SESSION_LOG" ]]; then
    "$AUDITOR" "$SESSION_LOG" 2>&1
  fi
fi
exit 0
