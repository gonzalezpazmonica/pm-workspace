#!/usr/bin/env bash
# PreToolUse hook (informativo) para Edit/Write sobre projects/*/CLAUDE.md.
# SPEC-PROJECT-CONTEXT-DISCIPLINE. NUNCA bloquea (exit 0 siempre).

set -u

# Source provider-agnostic env layer
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "${script_dir}/../../scripts/savia-env.sh" 2>/dev/null || true

ws="${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

# Tool input is passed via stdin as JSON. Best-effort parse: extract file_path.
payload="$(cat 2>/dev/null || true)"
file_path=""
if [[ -n "$payload" ]]; then
  file_path="$(printf '%s' "$payload" | python3 -c '
import json,sys
try:
    d=json.loads(sys.stdin.read())
    p=d.get("tool_input",{}).get("file_path") or d.get("file_path") or ""
    print(p)
except Exception:
    pass
' 2>/dev/null)"
fi

# Skip if not a projects/*/CLAUDE.md
if [[ -z "$file_path" ]]; then
  exit 0
fi
case "$file_path" in
  */projects/*/CLAUDE.md|projects/*/CLAUDE.md) ;;
  *) exit 0 ;;
esac

# Derive absolute path
abs="$file_path"
if [[ "$abs" != /* ]]; then
  abs="$ws/$file_path"
fi

[[ -f "$abs" ]] || exit 0

# Run audit (best-effort, informational; never blocks)
audit_script="$ws/scripts/project-context-audit.py"
[[ -x "$audit_script" ]] || exit 0

python3 "$audit_script" --file "$abs" 2>/dev/null | head -6 >&2 || true
exit 0
