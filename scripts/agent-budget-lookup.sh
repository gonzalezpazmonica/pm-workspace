#!/usr/bin/env bash
set -uo pipefail
# agent-budget-lookup.sh — Extract token_budget from agent frontmatter
# Usage: agent-budget-lookup.sh <agent-name>
# Output: integer (0 if not found). Exit 0 always.
# Respects CLAUDE_PROJECT_DIR for test isolation.

AGENT_NAME="${1:-}"
BASE_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AGENT_FILE="$BASE_DIR/.opencode/agents/${AGENT_NAME}.md"

if [[ -z "$AGENT_NAME" ]] || [[ ! -f "$AGENT_FILE" ]]; then
  echo "0"; exit 0
fi

BUDGET=$(awk '/^---$/{if(++c==2)exit} c==1 && /^token_budget:/{gsub(/[^0-9]/,"",$2);print $2}' "$AGENT_FILE" 2>/dev/null)
echo "${BUDGET:-0}"
exit 0
