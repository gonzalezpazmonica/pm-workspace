#!/usr/bin/env bash
set -uo pipefail
# savia-orchestrator-helper.sh — SPEC-127 Slice 4 + SE-106
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
#   4. tier — SE-106: split judges for a tribunal into tier0/tier1 JSON
#   5. judges — SE-106: list judges of a tribunal with their tier
#
# Subcommands:
#   bash scripts/savia-orchestrator-helper.sh mode
#       Returns "fan-out" or "single-shot" on stdout.
#
#   bash scripts/savia-orchestrator-helper.sh inline-prompt <agent-name>
#       Reads .opencode/agents/<agent-name>.md, strips frontmatter, prints
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
#   bash scripts/savia-orchestrator-helper.sh tier <tribunal_type> [judges_csv]
#       Returns JSON: {"tier0": [...], "tier1": [...]}
#       tribunal_type: truth_tribunal | court | recommendation_tribunal
#       judges_csv: optional override; if omitted, uses canonical defaults.
#       If TRIBUNAL_FORCE_FULL_PANEL=1, tier0 is empty and all judges go to tier1.
#
#   bash scripts/savia-orchestrator-helper.sh judges <tribunal_type>
#       Lists all judges for the tribunal with their tier assignment.
#       Format: "<tier>\t<judge-name>" (tab-separated), sorted tier then name.
#
# This helper does NOT call any LLM. It is provider-agnostic: branches on
# capability (savia_has_task_fan_out) not vendor name. Cero hardcoded vendor
# strings (PV-06).
#
# Reference: SPEC-127 Slice 4 AC-4.1, AC-4.2, AC-4.3
# Reference: SE-106 tiered tribunal execution
# Reference: docs/rules/domain/subagent-fallback-mode.md
# Reference: docs/rules/domain/provider-agnostic-env.md
# Reference: docs/rules/domain/tribunal-execution.md

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
AGENTS_DIR="${AGENTS_DIR:-${ROOT}/.opencode/agents}"
ENV_SCRIPT="${ROOT}/scripts/savia-env.sh"

usage() {
  cat <<USG
Usage: savia-orchestrator-helper.sh <subcommand> [args]

Subcommands:
  mode                              Print "fan-out" or "single-shot"
  inline-prompt <agent-name>        Print agent's system prompt (no frontmatter)
  wrap <agent-name> <file>          Wrap raw inline output in JSON envelope
  list-agents                       List available agents
  tier <tribunal_type> [judges_csv] Print {"tier0":[...],"tier1":[...]} JSON
  judges <tribunal_type>            List judges with tier (tab-separated)

tribunal_type values: truth_tribunal | court | recommendation_tribunal

Override: TRIBUNAL_FORCE_FULL_PANEL=1 puts all judges in tier1 (full panel).
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

# ── SE-106: Tiered tribunal helpers ────────────────────────────────────────

# Canonical tier assignments per tribunal type.
# Format: "tier0_judge1,tier0_judge2,...|tier1_judge1,tier1_judge2,..."
_tribunal_tiers() {
  local tribunal_type="$1"
  case "$tribunal_type" in
    truth_tribunal)
      # Tier 0: compliance first (PII/regulatory absolute veto), then hallucination,
      # then factuality. Tier 1: remaining 4 judges in parallel.
      echo "compliance-judge,hallucination-judge,factuality-judge|source-traceability-judge,coherence-judge,calibration-judge,completeness-judge"
      ;;
    court)
      # Tier 0: security first (OWASP/credentials — merge blocker), then correctness
      # (broken logic/tests — rest is moot if it fails).
      # Tier 1: remaining judges + optional pr-agent-judge.
      echo "security-judge,correctness-judge|architecture-judge,cognitive-judge,spec-judge"
      ;;
    recommendation_tribunal)
      # Tiered execution does NOT apply — sync latency p95 <3s constraint.
      # All judges run in parallel. This helper returns them all in tier1.
      echo "|memory-conflict-judge,rule-violation-judge,hallucination-fast-judge,expertise-asymmetry-judge"
      ;;
    *)
      echo "ERROR: unknown tribunal_type: $tribunal_type" >&2
      echo "  valid values: truth_tribunal, court, recommendation_tribunal" >&2
      return 2
      ;;
  esac
}

# tier <tribunal_type> [judges_csv]
# Emits JSON: {"tier0": [...], "tier1": [...]}
# If TRIBUNAL_FORCE_FULL_PANEL=1, tier0=[] and all judges go to tier1.
tier() {
  local tribunal_type="${1:-}"
  local judges_override="${2:-}"

  if [[ -z "$tribunal_type" ]]; then
    echo "ERROR: tier requires <tribunal_type>" >&2
    return 2
  fi

  local tier_spec
  tier_spec=$(_tribunal_tiers "$tribunal_type") || return $?

  local t0_raw t1_raw
  t0_raw="${tier_spec%%|*}"
  t1_raw="${tier_spec##*|}"

  # If caller supplies override CSV, split it: first half -> tier0, rest -> tier1
  if [[ -n "$judges_override" ]]; then
    # When override provided, use canonical tier split but filter to supplied judges
    local all_judges="$judges_override"
    local canonical_t0=",$t0_raw,"
    t0_raw=""
    t1_raw=""
    local judge
    IFS=',' read -ra judge_arr <<< "$all_judges"
    for judge in "${judge_arr[@]}"; do
      judge="${judge// /}"
      if [[ "$canonical_t0" == *",${judge},"* ]]; then
        t0_raw="${t0_raw:+${t0_raw},}${judge}"
      else
        t1_raw="${t1_raw:+${t1_raw},}${judge}"
      fi
    done
  fi

  # TRIBUNAL_FORCE_FULL_PANEL=1 -> demote all tier0 judges to tier1
  if [[ "${TRIBUNAL_FORCE_FULL_PANEL:-0}" == "1" ]]; then
    if [[ -n "$t0_raw" ]]; then
      t1_raw="${t0_raw}${t1_raw:+,${t1_raw}}"
    fi
    t0_raw=""
  fi

  # Build JSON arrays from comma-separated strings
  python3 - "$t0_raw" "$t1_raw" <<'PY'
import json, sys
def csv_to_list(s): return [x.strip() for x in s.split(",") if x.strip()] if s else []
tier0 = csv_to_list(sys.argv[1])
tier1 = csv_to_list(sys.argv[2])
print(json.dumps({"tier0": tier0, "tier1": tier1}, ensure_ascii=False))
PY
}

# judges <tribunal_type>
# Lists all judges for the tribunal with their tier assignment.
# Output: "<tier>\t<judge-name>" per line, sorted by tier then name.
judges() {
  local tribunal_type="${1:-}"
  if [[ -z "$tribunal_type" ]]; then
    echo "ERROR: judges requires <tribunal_type>" >&2
    return 2
  fi

  local tier_spec
  tier_spec=$(_tribunal_tiers "$tribunal_type") || return $?

  local t0_raw t1_raw
  t0_raw="${tier_spec%%|*}"
  t1_raw="${tier_spec##*|}"

  local judge
  if [[ -n "$t0_raw" ]]; then
    IFS=',' read -ra arr <<< "$t0_raw"
    for judge in "${arr[@]}"; do
      judge="${judge// /}"
      [[ -n "$judge" ]] && printf "tier0\t%s\n" "$judge"
    done
  fi
  if [[ -n "$t1_raw" ]]; then
    IFS=',' read -ra arr <<< "$t1_raw"
    for judge in "${arr[@]}"; do
      judge="${judge// /}"
      [[ -n "$judge" ]] && printf "tier1\t%s\n" "$judge"
    done
  fi
}

case "${1:-}" in
  mode)           mode ;;
  inline-prompt)  shift; inline_prompt "${1:-}" ;;
  wrap)           shift; wrap "${1:-}" "${2:-}" ;;
  list-agents)    list_agents ;;
  tier)           shift; tier "${1:-}" "${2:-}" ;;
  judges)         shift; judges "${1:-}" ;;
  --help|-h|help) usage ;;
  *) echo "unknown subcommand: ${1:-(none)}" >&2; usage >&2; exit 2 ;;
esac
