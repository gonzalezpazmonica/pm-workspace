#!/usr/bin/env bash
# tool-result-trim.sh — Deterministic hard cap for tool result output
# Ref: SPEC-087 — Tool Result Trimming
# Usage: echo "content" | bash scripts/tool-result-trim.sh
#   Reads stdin, outputs trimmed content on stdout.
#   If content > TOOL_RESULT_MAX_CHARS (default 5000), truncates and appends message.
#   Exit 0 always (trimming is informational, never blocks).
set -uo pipefail

MAX_CHARS="${TOOL_RESULT_MAX_CHARS:-5000}"

# Read all stdin
content=$(cat)

# If empty or within limit, pass through unchanged
if [[ -z "$content" ]] || [[ ${#content} -le $MAX_CHARS ]]; then
  printf '%s' "$content"
  exit 0
fi

# Truncate and append informational message
printf '%s' "${content:0:$MAX_CHARS}"
printf '\n[...truncado a %s chars]' "$MAX_CHARS"
exit 0
