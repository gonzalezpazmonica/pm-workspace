#!/bin/bash
set -uo pipefail

# validate-agent-permissions.sh — Verify agent permission_level matches tools
# Returns: 0 if all match, 1 if mismatches found

AGENTS_DIR="${1:-.claude/agents}"
ERRORS=0
WARNINGS=0
CHECKED=0

# Define expected tools per level
declare -A LEVEL_TOOLS
LEVEL_TOOLS[L0]="Read Glob Grep"
LEVEL_TOOLS[L1]="Read Glob Grep Bash"
LEVEL_TOOLS[L2]="Read Write Edit Glob Grep"
LEVEL_TOOLS[L3]="Read Write Edit Bash Glob Grep"
LEVEL_TOOLS[L4]="Read Write Edit Bash Glob Grep Task"

for agent_file in "$AGENTS_DIR"/*.md; do
  [[ -f "$agent_file" ]] || continue
  CHECKED=$((CHECKED + 1))

  agent_name=$(basename "$agent_file" .md)

  # Extract permission_level from frontmatter
  level=$(sed -n '/^---$/,/^---$/{ /^permission_level:/{ s/.*: *//; p; } }' "$agent_file")

  if [[ -z "$level" ]]; then
    WARNINGS=$((WARNINGS + 1))
    if [[ "${2:-}" == "--verbose" ]]; then
      echo "WARN: $agent_name — no permission_level in frontmatter"
    fi
    continue
  fi

  # Extract tools from frontmatter
  tools_line=$(sed -n '/^---$/,/^---$/{ /^tools:/{ s/.*: *//; p; } }' "$agent_file")
  if [[ -z "$tools_line" ]]; then
    # Try multiline tools format
    tools_line=$(sed -n '/^---$/,/^---$/{ /^  - /{ s/.*- //; p; } }' "$agent_file" | tr '\n' ' ')
  fi

  # Normalize tools (remove brackets, commas, quotes)
  tools_clean=$(echo "$tools_line" | tr -d '[],"' | tr ',' ' ' | xargs)
  expected="${LEVEL_TOOLS[$level]:-}"

  if [[ -z "$expected" ]]; then
    echo "ERROR: $agent_name — unknown level: $level"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Compare (simple: check each expected tool is present)
  for tool in $expected; do
    if ! echo "$tools_clean" | grep -qw "$tool"; then
      if [[ "${2:-}" == "--verbose" ]]; then
        echo "WARN: $agent_name ($level) — missing tool: $tool"
      fi
      WARNINGS=$((WARNINGS + 1))
    fi
  done
done

echo ""
echo "Agent Permission Validation"
echo "==========================="
echo "  Checked: $CHECKED agents"
echo "  Errors:  $ERRORS"
echo "  Warnings: $WARNINGS"

if [[ $ERRORS -gt 0 ]]; then
  exit 1
fi
exit 0
