#!/usr/bin/env bash
set -uo pipefail
# judge-auto-router.sh — SE-273 S1: PostToolUse hook
#
# Invokes judge-trigger-detector.sh after tool execution. Non-blocking
# by default (triggers are logged, not enforced). Only rule-violation
# judge can block.
#
# Registered in settings.json as PostToolUse hook.
# Master switch: SAVIA_JUDGE_AUTO_ROUTER=off disables entirely.

[[ "${SAVIA_JUDGE_AUTO_ROUTER:-on}" == "off" ]] && exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HOOK_DIR/../.." && pwd)"
SCRIPT="$ROOT/scripts/judge-trigger-detector.sh"
INPUT="$1"

# Extract tool name from the JSON envelope or from context
TOOL=""
if echo "$INPUT" | grep -q '"tool_name"' 2>/dev/null; then
  TOOL=$(echo "$INPUT" | grep -oP '"tool_name"\s*:\s*"\K[^"]+' 2>/dev/null || echo "")
fi
[[ -z "$TOOL" ]] && TOOL="${SAVIA_LAST_TOOL:-unknown}"

# Extract tool output for content scanning
OUTPUT=""
if echo "$INPUT" | grep -q '"output"' 2>/dev/null; then
  OUTPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('output',''))" 2>/dev/null || echo "")
fi

# Skip if no content to scan
[[ -z "$OUTPUT" || "$OUTPUT" == "null" ]] && exit 0

# Run detection
TMP_INPUT=$(mktemp)
echo "$OUTPUT" > "$TMP_INPUT"
bash "$SCRIPT" "$TOOL" "$TMP_INPUT" 2>&1
DETECTOR_EXIT=$?
rm -f "$TMP_INPUT"

# If rule-violation was detected (blocking), the detector exits with
# non-zero. Forward the block signal.
if [[ $DETECTOR_EXIT -gt 0 ]]; then
  # Check if any blocking trigger fired
  if grep -q '"blocking":true' "$ROOT/output/judge-triggers.jsonl" 2>/dev/null; then
    echo "[JUDGE-AUTO-ROUTER] blocking trigger fired — forwarding signal" >&2
  fi
fi

exit 0  # Never block the tool itself; blocking is advisory via the trigger log
