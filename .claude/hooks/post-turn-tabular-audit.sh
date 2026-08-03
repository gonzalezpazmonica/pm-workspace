#!/usr/bin/env bash
set -uo pipefail
# post-turn-tabular-audit.sh — Capa 4: self-audit after each turn

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDITOR="$SCRIPT_DIR/../../scripts/tabular-self-audit.sh"

if [[ -x "$AUDITOR" ]]; then
  SESSION_LOG="${SAVIA_SESSION_LOG:-}"
  if [[ -n "$SESSION_LOG" && -f "$SESSION_LOG" ]]; then
    "$AUDITOR" "$SESSION_LOG" 2>&1
  elif [[ ! -t 0 ]]; then
    INPUT=$(cat)
    echo "$INPUT" | "$AUDITOR" /dev/stdin 2>&1 || true
  fi
fi
exit 0
