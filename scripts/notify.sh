#!/usr/bin/env bash
# notify.sh — Cross-platform desktop notifications for Savia
# Usage: ./scripts/notify.sh "Title" "Message" [--urgency low|normal|critical]
# Supports: Linux (notify-send), macOS (osascript), fallback (echo)
# ─────────────────────────────────────────────────────────────────
set -uo pipefail
cat /dev/stdin > /dev/null 2>&1 || true

TITLE="${1:-Savia}"
MESSAGE="${2:-}"
URGENCY="normal"

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --urgency) URGENCY="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -z "$MESSAGE" ] && { echo "Usage: $0 \"Title\" \"Message\" [--urgency low|normal|critical]" >&2; exit 1; }

# ── Linux (notify-send) ──
if command -v notify-send >/dev/null 2>&1; then
  notify-send -u "$URGENCY" "$TITLE" "$MESSAGE" 2>/dev/null
  exit 0
fi

# ── macOS (osascript) ──
if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null
  exit 0
fi

# ── Fallback: terminal bell + echo ──
printf '\a'
echo "[$TITLE] $MESSAGE"
