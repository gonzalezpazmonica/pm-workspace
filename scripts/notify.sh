#!/usr/bin/env bash
# notify.sh — Cross-platform desktop notifications for Savia
# Usage: ./scripts/notify.sh "Title" "Message" [--urgency low|normal|critical]
# Supports: Linux (notify-send), macOS (osascript), fallback (echo)
# ─────────────────────────────────────────────────────────────────
set -uo pipefail
cat /dev/stdin > /dev/null 2>&1 || true

TITLE=""
MESSAGE=""
URGENCY="normal"
CHANNEL=""
CHANNEL_SET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --urgency) URGENCY="$2"; shift 2 ;;
    --channel) CHANNEL="$2"; CHANNEL_SET=true; shift 2 ;;
    --message) MESSAGE="$2"; shift 2 ;;
    *)
      if [[ -z "$TITLE" ]]; then TITLE="$1"; else MESSAGE="$1"; fi
      shift ;;
  esac
done

TITLE="${TITLE:-Savia}"
[[ "$CHANNEL_SET" == "true" && -z "$CHANNEL" ]] && { echo "Error: --channel requires a non-empty value" >&2; exit 1; }
if [[ "$CHANNEL_SET" == "true" && -n "$CHANNEL" ]]; then
  case "$CHANNEL" in
    desktop|slack|nctalk|whatsapp|email) ;;
    *) echo "Error: unknown channel type '$CHANNEL'. Valid: desktop, slack, nctalk, whatsapp, email" >&2; exit 1 ;;
  esac
fi
[ -z "$MESSAGE" ] && { echo "Usage: $0 \"Title\" \"Message\" [--urgency low|normal|critical] [--channel TYPE --message TEXT]" >&2; exit 1; }

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
