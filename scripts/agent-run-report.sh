#!/usr/bin/env bash
# agent-run-report.sh — SE-148: AgentRunSummary report generator
# Reads data/agent-actuals.jsonl and produces human-readable tables.
#
# Usage:
#   agent-run-report.sh                   → summary table (all agents)
#   agent-run-report.sh --unused-tools [N] → tools declared but never invoked in last N runs (default 50)
#   agent-run-report.sh --error-prone     → tool calls with error_rate > 20%
#   agent-run-report.sh --raw <run_id>    → pretty-print a single run record
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}}}"
DEFAULT_LOG="$WORKSPACE_DIR/data/agent-actuals.jsonl"
AGENT_ACTUALS_LOG="${AGENT_ACTUALS_LOG:-$DEFAULT_LOG}"

# ── Guards ───────────────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required for agent-run-report.sh" >&2
  exit 1
fi

if [[ ! -f "$AGENT_ACTUALS_LOG" ]]; then
  echo "No telemetry file found at: $AGENT_ACTUALS_LOG"
  echo "Run 'agent-run-logger.sh start <agent> <task>' to generate data."
  exit 0
fi

# Filter to only schema_version 2 records (SE-148 enriched)
_v2_records() {
  grep '"schema_version"' "$AGENT_ACTUALS_LOG" 2>/dev/null \
    | jq -s '[.[] | select(.schema_version == "2")]' 2>/dev/null \
  || echo "[]"
}

# ── Summary table ─────────────────────────────────────────────────────────────
cmd_summary() {
  local records
  records="$(_v2_records)"

  local count
  count="$(echo "$records" | jq 'length')"

  if [[ "$count" -eq 0 ]]; then
    echo "No SE-148 agent run records found in $AGENT_ACTUALS_LOG"
    echo "(Legacy spec-estimation records are present but not shown — they use a different schema.)"
    exit 0
  fi

  echo ""
  echo "╔══════════════════════════════════════════════════════════════════════════╗"
  echo "║              AgentRunSummary Report  (SE-148)                           ║"
  echo "╚══════════════════════════════════════════════════════════════════════════╝"
  echo ""
  printf "%-26s  %5s  %11s  %12s  %10s  %9s\n" \
    "AGENT" "RUNS" "AVG_DUR(s)" "TOOLS_UNUSED" "ERROR_RATE" "AVG_COST"
  echo "──────────────────────────────────────────────────────────────────────────"

  echo "$records" | jq -r '
    group_by(.agent)[] |
    . as $group |
    ($group | length) as $runs |
    {
      agent:       $group[0].agent,
      runs:        $runs,
      avg_dur:     ([$group[].duration_s | select(. != null)] | if length > 0 then (add / length | . * 10 | round / 10) else null end),
      avg_unused:  ([$group[].tools_unused | length] | add / $runs | . * 10 | round / 10),
      error_rate: (
        ($group | map(.tool_status // {} | to_entries[] | .value | (.error // 0)) | add // 0) as $errs |
        ($group | map(.tool_status // {} | to_entries[] | .value | values | add) | add // 0) as $total |
        if $total > 0 then ($errs * 100 / $total | . * 10 | round / 10) else 0 end
      ),
      avg_cost: ([$group[].cost_usd | select(. != null)] | if length > 0 then (add / length | . * 10000 | round / 10000) else null end)
    } |
    [
      .agent,
      (.runs | tostring),
      (if .avg_dur then (.avg_dur | tostring) else "—" end),
      (.avg_unused | tostring),
      ((.error_rate | tostring) + "%"),
      (if .avg_cost then ("$" + (.avg_cost | tostring)) else "—" end)
    ] | @tsv
  ' | while IFS=$'\t' read -r agent runs avg_dur tools_unused error_rate avg_cost; do
    printf "%-26s  %5s  %11s  %12s  %10s  %9s\n" \
      "$agent" "$runs" "$avg_dur" "$tools_unused" "$error_rate" "$avg_cost"
  done

  echo ""
  echo "Total SE-148 runs: $count  |  Log: $AGENT_ACTUALS_LOG"
  echo ""
}

# ── Unused tools ─────────────────────────────────────────────────────────────
cmd_unused_tools() {
  local limit="${1:-50}"
  local records
  records="$(_v2_records)"

  echo ""
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║        Unused Tools (last $limit runs)  (SE-148)                        ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo ""
  printf "%-26s  %-14s  %s\n" "AGENT" "RUN_ID_SHORT" "UNUSED_TOOLS"
  echo "────────────────────────────────────────────────────────────────────"

  echo "$records" | jq -r \
    --argjson limit "$limit" '
    .[-$limit:] |
    .[] |
    select((.tools_unused | length) > 0) |
    [
      .agent,
      (.run_id | .[0:8]),
      (.tools_unused | join(", "))
    ] | @tsv
  ' | while IFS=$'\t' read -r agent run_short tools; do
    printf "%-26s  %-14s  %s\n" "$agent" "$run_short" "$tools"
  done

  echo ""
}

# ── Error-prone tools ─────────────────────────────────────────────────────────
cmd_error_prone() {
  local threshold=20
  local records
  records="$(_v2_records)"

  echo ""
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║        Error-Prone Tool Calls (error_rate > ${threshold}%)  (SE-148)        ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo ""
  printf "%-26s  %-12s  %8s  %8s  %10s\n" "AGENT" "TOOL" "OK" "ERROR" "ERR_RATE"
  echo "────────────────────────────────────────────────────────────────────"

  echo "$records" | jq -r \
    --argjson threshold "$threshold" '
    .[] |
    . as $run |
    (.tool_status // {}) | to_entries[] |
    . as $entry |
    ($entry.value.ok // 0) as $ok |
    ($entry.value.error // 0) as $err |
    (($ok + $err) | if . > 0 then ($err * 100 / .) else 0 end) as $rate |
    select($rate > $threshold) |
    [
      $run.agent,
      $entry.key,
      ($ok | tostring),
      ($err | tostring),
      (($rate * 10 | round / 10 | tostring) + "%")
    ] | @tsv
  ' | sort -t$'\t' -k5 -rn \
    | while IFS=$'\t' read -r agent tool ok err rate; do
    printf "%-26s  %-12s  %8s  %8s  %10s\n" "$agent" "$tool" "$ok" "$err" "$rate"
  done

  echo ""
}

# ── Raw single record ─────────────────────────────────────────────────────────
cmd_raw() {
  local run_id="${1:?run_id required}"
  grep -F "\"run_id\":\"$run_id\"" "$AGENT_ACTUALS_LOG" 2>/dev/null \
    | tail -1 \
    | jq . 2>/dev/null \
  || echo "run_id '$run_id' not found"
}

# ── Dispatcher ───────────────────────────────────────────────────────────────
SUBCOMMAND="${1:-summary}"
shift || true

case "$SUBCOMMAND" in
  summary|"")     cmd_summary ;;
  --unused-tools) cmd_unused_tools "${1:-50}" ;;
  --error-prone)  cmd_error_prone ;;
  --raw)          cmd_raw "$@" ;;
  *)
    echo "Usage: agent-run-report.sh [summary|--unused-tools [N]|--error-prone|--raw <run_id>]" >&2
    exit 1 ;;
esac
