#!/usr/bin/env bash
set -uo pipefail
# agent-budget-lookup.sh — Extract token budget from agent frontmatter
# Usage: agent-budget-lookup.sh <agent-name>
# Output: integer (0 if not found). Exit 0 always.
# Supports both legacy scalar (token_budget: N) and SPEC-156 nested form
# (token_budget: \n  context_window_target: N). Returns context_window_target
# when nested, else the scalar value.

AGENT_NAME="${1:-}"
BASE_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AGENT_FILE="$BASE_DIR/.opencode/agents/${AGENT_NAME}.md"

if [[ -z "$AGENT_NAME" ]] || [[ ! -f "$AGENT_FILE" ]]; then
  echo "0"; exit 0
fi

BUDGET=$(awk '
  /^---$/{ if(++c==2) exit; next }
  c!=1 { next }
  /^token_budget:[[:space:]]*[0-9]+/ { gsub(/[^0-9]/,"",$2); print $2; exit }
  /^token_budget:[[:space:]]*$/ { in_tb=1; next }
  in_tb && /^[[:space:]]+context_window_target:[[:space:]]*[0-9]+/ {
    gsub(/[^0-9]/,"",$2); print $2; exit
  }
  in_tb && /^[^[:space:]]/ { in_tb=0 }
' "$AGENT_FILE" 2>/dev/null)
echo "${BUDGET:-0}"
exit 0
