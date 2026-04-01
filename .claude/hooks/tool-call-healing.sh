#!/bin/bash
set -uo pipefail
# tool-call-healing.sh — SPEC-141: Validate tool parameters before execution
# PreToolUse hook: catches common errors (empty paths, missing files) and
# provides diagnostic hints instead of letting tools fail cryptically.
# Matcher: Read|Edit|Write|Glob|Grep

# Tier: standard
LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

INPUT=$(cat 2>/dev/null || true)
[[ -z "$INPUT" ]] && exit 0

TOOL=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
[[ -z "$TOOL" ]] && exit 0

# Extract file_path parameter (common to Read, Edit, Write)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")

# Extract pattern for Glob/Grep
PATTERN=$(echo "$INPUT" | grep -o '"pattern":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")

case "$TOOL" in
  Read|Edit)
    # Validate file exists for Read/Edit
    if [[ -n "$FILE_PATH" ]] && [[ ! -f "$FILE_PATH" ]]; then
      # Check if it's a close match (typo detection)
      DIR=$(dirname "$FILE_PATH")
      BASE=$(basename "$FILE_PATH")
      if [[ -d "$DIR" ]]; then
        SIMILAR=$(find "$DIR" -maxdepth 1 -name "${BASE%.*}*" -type f 2>/dev/null | head -3 | tr '\n' ', ')
        if [[ -n "$SIMILAR" ]]; then
          echo "File not found: $FILE_PATH. Similar files: ${SIMILAR%, }" >&2
        fi
      fi
    fi
    # Empty file_path check
    if [[ -z "$FILE_PATH" ]]; then
      echo "BLOCKED: $TOOL called with empty file_path" >&2
      exit 2
    fi
    ;;
  Write)
    # For Write, validate parent directory exists
    if [[ -n "$FILE_PATH" ]]; then
      DIR=$(dirname "$FILE_PATH")
      if [[ ! -d "$DIR" ]]; then
        echo "BLOCKED: Write to $FILE_PATH — parent directory does not exist: $DIR" >&2
        exit 2
      fi
    fi
    if [[ -z "$FILE_PATH" ]]; then
      echo "BLOCKED: Write called with empty file_path" >&2
      exit 2
    fi
    ;;
  Glob|Grep)
    # Empty pattern check
    if [[ -z "$PATTERN" ]]; then
      echo "BLOCKED: $TOOL called with empty pattern" >&2
      exit 2
    fi
    ;;
esac

# All checks passed
exit 0
