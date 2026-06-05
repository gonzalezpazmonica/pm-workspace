#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# recommendation-tribunal-followup.sh — SPEC-125 Slice 3 hook.
#
# Captures the user's NEXT-TURN reply when the previous Savia output included
# a [TRIBUNAL: WARN] or [TRIBUNAL: VETO] banner. The reply is the calibration
# signal — was the verdict right? was it overblocking? was it missing a real
# problem? — and gets recorded on the original audit-trail JSON record so
# scripts/recommendation-tribunal/calibrate.sh can derive feedback memories
# in the next batch.
#
# This file is the WIRE-READY hook. To activate it, add to .claude/settings.json:
#   "hooks": {
#     "UserPromptSubmit": [
#       {"matcher": "*", "hooks": [{"type": "command", "command":
#         "$CLAUDE_PROJECT_DIR/.opencode/hooks/recommendation-tribunal-followup.sh"}]}
#     ]
#   }
#
# Until activated, this hook is a NO-OP: just an executable file living in
# .opencode/hooks/. Activation is a separate, deliberate step the human
# user must take after reviewing the entire SPEC-125 Slice 3 batch.
#
# When wired, the hook reads the previous turn's draft_hash from a small
# pointer file managed by recommendation-tribunal-pre-output.sh and forwards
# the current user prompt to followup-record.sh.
#
# Exit codes:
#   0  ok — followup recorded (or no banner on previous turn — pass-through)
#   1  fatal — script broken (must not block the turn — caller should ignore)

# ── NO-OP guard ─────────────────────────────────────────────────────────────
if [ "${RECOMMENDATION_TRIBUNAL_FOLLOWUP_ACTIVE:-0}" != "1" ]; then
  exit 0
fi

# ── Real wiring (only runs when explicitly activated) ───────────────────────

ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
POINTER_FILE="${RECOMMENDATION_TRIBUNAL_LAST_BANNER_HASH:-$ROOT_DIR/.opencode/state/recommendation-tribunal-last-banner.txt}"
FOLLOWUP_SCRIPT="$ROOT_DIR/scripts/recommendation-tribunal/followup-record.sh"

# Read previous-turn hash pointer; if missing, no banner was emitted -> exit clean.
[ -f "$POINTER_FILE" ] || exit 0
last_hash=$(cat "$POINTER_FILE" 2>/dev/null | tr -d '[:space:]')
[ -n "$last_hash" ] || exit 0

# Read user prompt from stdin (Claude Code passes JSON envelope; opencode passes raw).
input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

# Try JSON envelope first (Claude Code), fall back to raw text.
prompt_text=$(printf '%s' "$input" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
  d = json.loads(raw)
  print(d.get("prompt") or d.get("user_prompt") or d.get("text") or raw, end="")
except Exception:
  print(raw, end="")
' 2>/dev/null)
[ -n "$prompt_text" ] || exit 0

# Forward to recorder; never let it block the turn.
[ -x "$FOLLOWUP_SCRIPT" ] || exit 0
"$FOLLOWUP_SCRIPT" --hash "$last_hash" --text "$prompt_text" --classification auto >/dev/null 2>&1 || true

# Clear pointer so we don't double-record on the next turn.
rm -f "$POINTER_FILE" 2>/dev/null || true
exit 0
