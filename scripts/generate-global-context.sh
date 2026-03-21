#!/usr/bin/env bash
# Generate compact global context for agent injection.
# Output: ~/.savia/global-context.txt (single line, ~100 tokens)
# Source: company profile + CLAUDE.local.md + active project
set -uo pipefail

OUTDIR="$HOME/.savia"
OUTFILE="$OUTDIR/global-context.txt"
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$OUTDIR"

parts=()

# Company identity
identity="$WORKSPACE_ROOT/.claude/profiles/company/identity.md"
if [[ -f "$identity" ]]; then
    name=$(grep -m1 '^name:' "$identity" 2>/dev/null | cut -d: -f2- | xargs)
    sector=$(grep -m1 '^sector:' "$identity" 2>/dev/null | cut -d: -f2- | xargs)
    [[ -n "$name" ]] && parts+=("$name")
    [[ -n "$sector" ]] && parts+=("$sector vertical")
fi

# Technology stack
tech="$WORKSPACE_ROOT/.claude/profiles/company/technology.md"
if [[ -f "$tech" ]]; then
    stack=$(grep -m1 '^primary_stack:' "$tech" 2>/dev/null | cut -d: -f2- | xargs)
    [[ -n "$stack" ]] && parts+=("$stack")
fi

# Team size from structure
structure="$WORKSPACE_ROOT/.claude/profiles/company/structure.md"
if [[ -f "$structure" ]]; then
    size=$(grep -m1 '^team_size:' "$structure" 2>/dev/null | cut -d: -f2- | xargs)
    [[ -n "$size" ]] && parts+=("${size} people")
fi

# PM tool and sprint from config
local_cfg="$WORKSPACE_ROOT/.claude/rules/pm-config.local.md"
if [[ -f "$local_cfg" ]]; then
    # Detect PM tool by checking which URL is configured
    if grep -q 'AZURE_DEVOPS_ORG_URL' "$local_cfg" 2>/dev/null; then
        parts+=("Azure DevOps")
    elif grep -q 'JIRA_BASE_URL' "$local_cfg" 2>/dev/null; then
        parts+=("Jira")
    fi
fi

# Sprint duration from pm-config
parts+=("2-week sprints")

# Language
parts+=("Spanish")

# Active project constraints (first project found)
for proj_claude in "$WORKSPACE_ROOT"/projects/*/CLAUDE.md; do
    [[ -f "$proj_claude" ]] || continue
    # Extract first constraint-like line
    constraint=$(grep -m1 -iE '(compliance|regulation|constraint|require)' "$proj_claude" 2>/dev/null | head -c 80)
    [[ -n "$constraint" ]] && parts+=("$constraint")
    break
done

# Join with " · " separator
ctx=$(IFS='·'; echo "${parts[*]}" | sed 's/·/ · /g')

if [[ -z "$ctx" ]]; then
    echo "No context data found. Ensure company profile exists." >&2
    echo "Run /company-setup first." >&2
    exit 1
fi

echo "$ctx" > "$OUTFILE"
echo "Global context generated: $OUTFILE"
echo "  Content: $ctx"
echo "  Tokens (est): $(( ${#ctx} / 4 ))"
