#!/bin/bash
set -uo pipefail
# cwd-changed-hook.sh — Auto-detect project context on directory change
# Hook: CwdChanged | Async: true
# When user navigates to a project dir, log context switch.

# Drain stdin (hook protocol)
cat > /dev/null 2>/dev/null || true

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

NEW_CWD="${CLAUDE_CWD:-$(pwd)}"
PROJECTS_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/projects"

# Check if we entered a project directory
if [[ "$NEW_CWD" == "$PROJECTS_DIR"/* ]]; then
  PROJECT_NAME=$(echo "$NEW_CWD" | sed "s|$PROJECTS_DIR/||" | cut -d'/' -f1)
  PROJECT_CLAUDE="$PROJECTS_DIR/$PROJECT_NAME/CLAUDE.md"

  if [[ -f "$PROJECT_CLAUDE" ]]; then
    echo "Project context: $PROJECT_NAME (CLAUDE.md found)"
  fi
fi

exit 0
