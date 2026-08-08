#!/usr/bin/env bash
# wrap-for-copilot.sh — SE-180 schema translator
#
# Wraps a Claude Code hook (.sh) so its stdout output is rewritten to the
# flat JSON schema Copilot CLI expects.
#
# Claude Code emits:        {"hookSpecificOutput":{"hookEventName":"X","additionalContext":"..."}}
# Copilot CLI expects:      {"additionalContext":"..."}
#
# The translator extracts the inner object, dropping `hookEventName`.
#
# Usage:  wrap-for-copilot.sh /absolute/path/to/hook.sh [args...]
#
# stdin is passed through to the underlying hook unchanged.
# stderr is passed through unchanged (Copilot prints it to the user).
# Exit code is preserved (Copilot interprets exit 2 as block regardless of stdout).
#
# Reference: SE-180
# Reference: docs.github.com/en/copilot/reference/hooks-configuration

set -uo pipefail

HOOK="${1:-}"
if [[ -z "$HOOK" ]]; then
  echo "wrap-for-copilot: missing hook path argument" >&2
  exit 4
fi
if [[ ! -x "$HOOK" ]]; then
  # Try to make it executable if it's readable
  if [[ -r "$HOOK" ]]; then
    chmod +x "$HOOK" 2>/dev/null || true
  fi
fi
if [[ ! -f "$HOOK" ]]; then
  echo "wrap-for-copilot: hook not found: $HOOK" >&2
  exit 4
fi

shift
# Execute the underlying hook. Capture stdout; pass stdin/stderr through.
# Use a temp file for stdout to avoid subshell variable issues.
STDOUT_TMP=$(mktemp)
trap 'rm -f "$STDOUT_TMP"' EXIT

bash "$HOOK" "$@" > "$STDOUT_TMP"
RC=$?

STDOUT_CONTENT=$(cat "$STDOUT_TMP")

# If the hook produced no output, exit with its code (nothing to translate).
if [[ -z "$STDOUT_CONTENT" ]]; then
  exit $RC
fi

# Translate: if output is Claude-wrapped (`hookSpecificOutput`), unwrap.
# Otherwise pass through (assume already flat or non-JSON).
python3 - "$STDOUT_CONTENT" <<'PY'
import json, sys

raw = sys.argv[1]
try:
    obj = json.loads(raw)
except json.JSONDecodeError:
    # Non-JSON stdout — pass through as-is
    print(raw, end="")
    sys.exit(0)

# Claude Code wrapper: {hookSpecificOutput: {hookEventName, ...rest}}
if isinstance(obj, dict) and "hookSpecificOutput" in obj and isinstance(obj["hookSpecificOutput"], dict):
    inner = dict(obj["hookSpecificOutput"])
    inner.pop("hookEventName", None)
    # Stop/SubagentStop wrapper: Claude uses {decision: "block", reason: "..."}
    # which Copilot CLI also accepts. No translation needed.
    # SessionStart: inner has additionalContext, which Copilot expects flat.
    # PreToolUse: inner has permissionDecision, which Copilot expects flat.
    # PostToolUse: inner has additionalContext or modifiedResult, which Copilot accepts flat.
    print(json.dumps(inner), end="")
else:
    # Already flat or non-wrapped — pass through
    print(json.dumps(obj), end="") if isinstance(obj, (dict, list)) else print(raw, end="")
PY

exit $RC
