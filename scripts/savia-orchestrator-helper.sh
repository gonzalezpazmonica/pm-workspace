#!/usr/bin/env bash
set -uo pipefail
# savia-orchestrator-helper.sh — SPEC-127 Slice 4
#
# Helper for orchestrator agents that delegate work to subagents via the
# Task tool. When the user's stack does NOT expose subagent fan-out
# (`savia_has_task_fan_out == false`), this helper provides:
#
#   1. mode — query the active orchestration mode ("fan-out" | "single-shot")
#   2. inline-prompt — extract a target agent's system prompt so the
#      orchestrator can run its logic inlined in a single LLM turn
#   3. wrapper — produce a JSON envelope matching the original Task output
#      shape, so audit trail / downstream consumers don't break
#
# Subcommands:
#   bash scripts/savia-orchestrator-helper.sh mode
#       Returns "fan-out" or "single-shot" on stdout.
#
#   bash scripts/savia-orchestrator-helper.sh inline-prompt <agent-name>
#       Reads .claude/agents/<agent-name>.md, strips frontmatter, prints
#       the system prompt body for inline execution.
#
#   bash scripts/savia-orchestrator-helper.sh wrap <agent-name> <output-file>
#       Reads the file with the orchestrator's inline-mode raw output and
#       wraps it in the JSON envelope:
#         {"agent": "<name>", "mode": "single-shot", "result": "<contents>"}
#
#   bash scripts/savia-orchestrator-helper.sh list-agents
#       Lists all agents available for inlining (basename without .md).
#
# This helper does NOT call any LLM. It is provider-agnostic: branches on
# capability (savia_has_task_fan_out) not vendor name. Cero hardcoded vendor
# strings (PV-06).
#
# Reference: SPEC-127 Slice 4 AC-4.1, AC-4.2, AC-4.3
# Reference: docs/rules/domain/subagent-fallback-mode.md
# Reference: docs/rules/domain/provider-agnostic-env.md

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
AGENTS_DIR="${AGENTS_DIR:-${ROOT}/.claude/agents}"
ENV_SCRIPT="${ROOT}/scripts/savia-env.sh"

usage() {
  cat <<USG
Usage: savia-orchestrator-helper.sh <subcommand> [args]

Subcommands:
  mode                          Print "fan-out" or "single-shot"
  inline-prompt <agent-name>    Print agent's system prompt (no frontmatter)
  wrap <agent-name> <file>      Wrap raw inline output in JSON envelope
  list-agents                   List available agents
USG
}

# Determine orchestration mode. Fan-out when has_task_fan_out is true;
# single-shot otherwise. Reads from savia-env.sh which respects
# ~/.savia/preferences.yaml + autodetect.
mode() {
  if [[ -f "$ENV_SCRIPT" ]]; then
    if bash "$ENV_SCRIPT" has-task-fan-out 2>/dev/null | grep -q "^yes$"; then
      echo "fan-out"
    else
      echo "single-shot"
    fi
  else
    # No env script available — assume worst case (no Task tool)
    echo "single-shot"
  fi
}

# Extract system prompt from an agent file. The frontmatter is delimited by
# `---` lines; everything after the second `---` is the prompt body.
inline_prompt() {
  local agent_name="$1"
  local agent_file="${AGENTS_DIR}/${agent_name}.md"
  if [[ ! -f "$agent_file" ]]; then
    echo "ERROR: agent not found: $agent_file" >&2
    return 2
  fi
  awk '
    /^---$/ { c++; next }
    c >= 2  { print }
  ' "$agent_file"
}

# Wrap raw output in a JSON envelope so downstream consumers (audit trail,
# verdict aggregators) get the same shape regardless of mode.
wrap() {
  local agent_name="$1" output_file="$2"
  if [[ ! -f "$output_file" ]]; then
    echo "ERROR: output file not found: $output_file" >&2
    return 2
  fi
  python3 - "$agent_name" "$output_file" <<'PY'
import json, sys
agent = sys.argv[1]
with open(sys.argv[2], "r") as f:
    raw = f.read()
print(json.dumps({
    "agent": agent,
    "mode": "single-shot",
    "result": raw,
}, ensure_ascii=False))
PY
}

list_agents() {
  if [[ ! -d "$AGENTS_DIR" ]]; then
    echo "ERROR: agents dir not found: $AGENTS_DIR" >&2
    return 3
  fi
  find "$AGENTS_DIR" -maxdepth 1 -type f -name "*.md" \
    -not -name "README.md" \
    -exec basename {} .md \; | sort
}

case "${1:-}" in
  mode)           mode ;;
  inline-prompt)  shift; inline_prompt "${1:-}" ;;
  wrap)           shift; wrap "${1:-}" "${2:-}" ;;
  list-agents)    list_agents ;;
  --help|-h|help) usage ;;
  *) echo "unknown subcommand: ${1:-(none)}" >&2; usage >&2; exit 2 ;;
esac
