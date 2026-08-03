#!/usr/bin/env bash
set -euo pipefail
# tabular-mcp-tool.sh — MCP tool: natural language query on tabular data
# Usage: tabular-mcp-tool.sh --source data.csv --question "trend of velocity?"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE=""
QUESTION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --source) SOURCE="$2"; shift 2 ;;
    --question) QUESTION="$2"; shift 2 ;;
    --help) echo "Usage: tabular-mcp-tool.sh --source <file> --question <text>"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ -z "$SOURCE" || -z "$QUESTION" ]]; then
  echo '{"error":"--source and --question required"}'
  exit 2
fi

# Step 1: Generate statistical profile
PROFILE=$("$SCRIPT_DIR/tabular-summarize.sh" "$SOURCE" 2>/dev/null || echo '{"error":"profile failed"}')

# Step 2: Combine question + profile for the LLM
# The LLM should receive this as context, not use it to compute
jq -n --arg q "$QUESTION" --argjson p "$PROFILE" '{
  question: $q,
  profile: $p,
  instruction: "Analyze the statistical profile above. Do NOT recompute numbers. Numbers in profile are exact. Provide qualitative interpretation only."
}'
