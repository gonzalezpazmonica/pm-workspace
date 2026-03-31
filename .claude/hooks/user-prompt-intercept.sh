#!/bin/bash
set -uo pipefail
# user-prompt-intercept.sh — Pre-process user input before Claude sees it
# Hook: UserPromptSubmit | Timeout: 3s
# Injects context hints for NL queries. Exit 0 + stdout = context shown to Claude.

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

# Read user input from stdin
USER_INPUT=$(cat 2>/dev/null || echo "")

# Skip if empty, slash command, or very short
if [[ -z "$USER_INPUT" ]] || [[ "$USER_INPUT" == /* ]] || [[ ${#USER_INPUT} -lt 5 ]]; then
  exit 0
fi

# Skip confirmations and simple responses
if echo "$USER_INPUT" | grep -qiE '^(s[ií]|no|ok|vale|claro|hecho|listo|cancelar|adelante|gracias)$'; then
  exit 0
fi

# No output = no injection. Just pass through.
exit 0
