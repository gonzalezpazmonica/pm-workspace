#!/usr/bin/env bash
set -uo pipefail
# validate-layer-contract.sh — PreToolUse hook for SE-001 layer contract
# Tier: standard
# Event: PreToolUse on Edit|Write
# Intercepts Core→Enterprise imports BEFORE they land on disk.

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"
fi

# Read hook input from stdin with explicit timeout
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(timeout 3 cat 2>/dev/null)
fi
[[ -z "$INPUT" ]] && exit 0

# Parse JSON with explicit error handling (no bare except)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    p = d.get('tool_input', {})
    print(p.get('file_path', p.get('path', '')))
except (json.JSONDecodeError, ValueError, KeyError):
    print('')
" 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0

CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    p = d.get('tool_input', {})
    c = p.get('content', p.get('new_string', ''))
    print(c[:8000])
except (json.JSONDecodeError, ValueError, KeyError):
    print('')
" 2>/dev/null)
[[ -z "$CONTENT" ]] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

# Normalize path relative to project
REL_PATH="${FILE_PATH#$PROJECT_DIR/}"

# Exclusions: validator scripts themselves, the enterprise dir, design docs and tests
case "$REL_PATH" in
  scripts/validate-layer-contract.sh) exit 0 ;;
  .claude/hooks/validate-layer-contract.sh) exit 0 ;;
  .claude/enterprise/*) exit 0 ;;
  docs/*) exit 0 ;;
  tests/*) exit 0 ;;
  CHANGELOG.md) exit 0 ;;
esac

# Only guard Core paths
case "$REL_PATH" in
  .claude/agents/*|.claude/commands/*|.claude/skills/*|.claude/rules/*|.claude/hooks/*|CLAUDE.md)
    ;;
  *)
    exit 0
    ;;
esac

# Check for forbidden pattern in the new content
if echo "$CONTENT" | grep -qE '@\.claude/enterprise/|\.claude/enterprise/' 2>/dev/null; then
  echo "BLOCKED: SE-001 layer contract violation" >&2
  echo "File: $REL_PATH" >&2
  echo "Core must never reference .claude/enterprise/ (unidirectional dependency)." >&2
  echo "If this file belongs in Enterprise, move it to .claude/enterprise/" >&2
  echo "If this is a legitimate design doc, place it in docs/propuestas/" >&2
  exit 2
fi

exit 0
