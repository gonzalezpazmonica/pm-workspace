#!/usr/bin/env bash
# savia-watch.sh — Live activity feed from Savia
# Usage: bash scripts/savia-watch.sh [--compact]

LOG="$HOME/.savia/live.log"
mkdir -p "$HOME/.savia"
touch "$LOG"

echo "━━ Savia Watch — actividad en tiempo real ━━"
echo "   Log: $LOG"
echo "   Ctrl+C para salir"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "${1:-}" == "--compact" ]]; then
  tail -f "$LOG" | grep --line-buffered -E "^.*(▶|✓|⚠|❌|━|⚙|✏|📝|🤖|⚡)"
else
  tail -f "$LOG"
fi
