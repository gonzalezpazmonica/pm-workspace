#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# delegation-guard.sh — Enforce delegation depth limits and toolset restrictions
# SPEC: SE-031 Delegation Toolset Enforcement
# Profile tier: standard

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Read hook input from stdin
INPUT=""
if [[ ! -t 0 ]]; then
  if command -v timeout >/dev/null 2>&1 && timeout --version >/dev/null 2>&1; then
    INPUT=$(timeout 3 cat 2>/dev/null) || true
  else
    INPUT=$(cat 2>/dev/null) || true
  fi
fi
[[ -z "$INPUT" ]] && exit 0

# Only apply to Agent tool invocations
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[[ "$TOOL_NAME" != "Agent" ]] && exit 0

# Check delegation depth
DEPTH="${SAVIA_DELEGATION_DEPTH:-0}"

if [[ "$DEPTH" -ge 1 ]]; then
  echo "BLOCKED [Delegation Guard]: recursive delegation attempt (depth=$DEPTH). Subagents cannot spawn further subagents." >&2
  exit 2
fi

# Extract agent prompt to check for delegation instructions
PROMPT=$(printf '%s' "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null) || true

if [[ -n "$PROMPT" ]] && [[ "$DEPTH" -ge 1 ]]; then
  # Check if subagent prompt tries to delegate
  if echo "$PROMPT" | grep -qiE '(delegate_task|spawn.*agent|launch.*agent|Agent\s*tool)'; then
    echo "BLOCKED [Delegation Guard]: subagent prompt contains delegation instructions at depth=$DEPTH" >&2
    exit 2
  fi
fi

# Log delegation for trace
AGENT_TYPE=$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // "general-purpose"' 2>/dev/null) || AGENT_TYPE="unknown"
AGENT_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_input.name // "unnamed"' 2>/dev/null) || AGENT_NAME="unnamed"

# Trace log (non-blocking)
TRACE_DIR="$PROJECT_DIR/output/delegation-trace"
mkdir -p "$TRACE_DIR" 2>/dev/null
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
printf '{"ts":"%s","depth":%d,"agent_type":"%s","agent_name":"%s","action":"allowed"}\n' \
  "$TS" "$DEPTH" "$AGENT_TYPE" "$AGENT_NAME" >> "$TRACE_DIR/delegations.jsonl" 2>/dev/null

exit 0
