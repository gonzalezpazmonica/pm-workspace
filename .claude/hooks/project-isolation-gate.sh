#!/usr/bin/env bash
# project-isolation-gate.sh — SE-093 Zero Project Leakage: warns on cross-project refs
# PreToolUse hook. NEVER blocks — only warns. Reads tool input from stdin.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"

HOOK_INPUT=$(timeout 2 cat /dev/stdin 2>/dev/null) || true
: "${HOOK_INPUT:=}"

WORKSPACE="${SAVIA_WORKSPACE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ACTIVE_FILE="${WORKSPACE}/.savia/active-project"
ACTIVE=""
[[ -n "${SAVIA_ACTIVE_PROJECT:-}" ]] && ACTIVE="$SAVIA_ACTIVE_PROJECT"
[[ -z "$ACTIVE" ]] && [[ -f "$ACTIVE_FILE" ]] && ACTIVE=$(head -1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
[[ -z "$ACTIVE" ]] && exit 0  # no active project → nothing to enforce

PROJECTS_DIR="${WORKSPACE}/projects"
[[ ! -d "$PROJECTS_DIR" ]] && exit 0

# Scan tool input for cross-project references
for proj_dir in "$PROJECTS_DIR"/*/; do
  [[ -d "$proj_dir" ]] || continue
  pname=$(basename "$proj_dir")
  [[ "$pname" == "$ACTIVE" ]] && continue
  [[ "$pname" == "savia-web" ]] && continue

  if echo "$HOOK_INPUT" | grep -q "projects/${pname}/" 2>/dev/null; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"CROSS-PROJECT: referencing %s while active is %s"}}\n' "$pname" "$ACTIVE"
  fi
done

exit 0
