#!/usr/bin/env bash
# agent-run-logger.sh — SE-148: AgentRunSummary telemetry logger
# Subcommands: start | tool-call | finish
# Writes/updates JSONL records in $AGENT_ACTUALS_LOG
# Backward-compatible: existing records without new fields are untouched.
#
# Usage:
#   agent-run-logger.sh start <agent> <task>
#     → prints run_id to stdout
#   agent-run-logger.sh tool-call <run_id> <tool> <status>
#     → status: ok|error|skipped|blocked|timeout|aborted
#   agent-run-logger.sh finish <run_id> <run_status>
#     → run_status: completed|aborted|timeout|error
set -uo pipefail

# ── Path resolution ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}}}"
DEFAULT_LOG="$WORKSPACE_DIR/data/agent-actuals.jsonl"
AGENT_ACTUALS_LOG="${AGENT_ACTUALS_LOG:-$DEFAULT_LOG}"

# Ensure parent directory exists
mkdir -p "$(dirname "$AGENT_ACTUALS_LOG")" 2>/dev/null || true
[[ -f "$AGENT_ACTUALS_LOG" ]] || touch "$AGENT_ACTUALS_LOG"

# ── Helpers ──────────────────────────────────────────────────────────────────
_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

_gen_id() {
  if command -v uuidgen &>/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    printf '%s-%s' "$(date +%s%N)" "$$"
  fi
}

_jq_available() { command -v jq &>/dev/null; }

# Read a single JSONL record by run_id; outputs JSON or empty string
_read_record() {
  local run_id="$1"
  if _jq_available; then
    grep -F "\"run_id\":\"$run_id\"" "$AGENT_ACTUALS_LOG" 2>/dev/null \
      | grep '"schema_version"' \
      | tail -1 \
    || true
  fi
}

# Rewrite the log replacing the record for run_id with new_json
_upsert_record() {
  local run_id="$1"
  local new_json="$2"
  local tmp
  tmp="$(mktemp)"

  # Write all lines except the existing record for this run_id
  while IFS= read -r line || [[ -n "$line" ]]; do
    if echo "$line" | grep -qF "\"run_id\":\"$run_id\"" 2>/dev/null \
       && echo "$line" | grep -q '"schema_version"' 2>/dev/null; then
      continue  # skip old record
    fi
    echo "$line" >> "$tmp"
  done < "$AGENT_ACTUALS_LOG"

  echo "$new_json" >> "$tmp"
  mv "$tmp" "$AGENT_ACTUALS_LOG"
}

# ── Subcommand: start ────────────────────────────────────────────────────────
cmd_start() {
  local agent="${1:?agent name required}"
  local task="${2:?task description required}"
  local run_id
  run_id="$(_gen_id)"
  local now
  now="$(_now)"

  if _jq_available; then
    local record
    record="$(jq -cn \
      --arg schema_version "2" \
      --arg run_id         "$run_id" \
      --arg agent          "$agent" \
      --arg task           "$task" \
      --arg started_at     "$now" \
      --arg run_status     "running" \
      '{
        schema_version:   $schema_version,
        run_id:           $run_id,
        agent:            $agent,
        task:             $task,
        started_at:       $started_at,
        finished_at:      null,
        duration_s:       null,
        run_status:       $run_status,
        tools_available:  [],
        tools_invoked:    {},
        tools_unused:     [],
        tool_status:      {},
        models_used:      [],
        tokens_in:        0,
        tokens_out:       0,
        cost_usd:         null
      }')"
    echo "$record" >> "$AGENT_ACTUALS_LOG"
  else
    # Fallback: minimal JSON without jq
    echo "{\"schema_version\":\"2\",\"run_id\":\"$run_id\",\"agent\":\"$agent\",\"task\":\"$task\",\"started_at\":\"$now\",\"finished_at\":null,\"duration_s\":null,\"run_status\":\"running\",\"tools_available\":[],\"tools_invoked\":{},\"tools_unused\":[],\"tool_status\":{},\"models_used\":[],\"tokens_in\":0,\"tokens_out\":0,\"cost_usd\":null}" \
      >> "$AGENT_ACTUALS_LOG"
  fi

  echo "$run_id"
}

# ── Subcommand: tool-call ────────────────────────────────────────────────────
cmd_tool_call() {
  local run_id="${1:?run_id required}"
  local tool="${2:?tool name required}"
  local status="${3:?status required}"

  # Validate status
  case "$status" in
    ok|error|skipped|blocked|timeout|aborted) ;;
    *) echo "ERROR: invalid status '$status'. Use: ok|error|skipped|blocked|timeout|aborted" >&2; exit 1;;
  esac

  if ! _jq_available; then
    echo "WARNING: jq not available — tool-call telemetry skipped" >&2
    return 0
  fi

  local existing
  existing="$(_read_record "$run_id")"

  if [[ -z "$existing" ]]; then
    echo "ERROR: run_id '$run_id' not found in $AGENT_ACTUALS_LOG" >&2
    exit 1
  fi

  local updated
  updated="$(echo "$existing" | jq -c \
    --arg tool   "$tool" \
    --arg status "$status" \
    '
    # Increment tools_invoked counter
    .tools_invoked[$tool] = ((.tools_invoked[$tool] // 0) + 1) |

    # Update tool_status counters
    .tool_status[$tool] = (
      (.tool_status[$tool] // {}) |
      .[$status] = ((.[$status] // 0) + 1)
    ) |

    # Track models_used (tool name used as proxy when no model env var)
    if env.SAVIA_MODEL_ID then
      .models_used = (.models_used + [env.SAVIA_MODEL_ID] | unique)
    else . end
    ')"

  _upsert_record "$run_id" "$updated"
}

# ── Subcommand: finish ───────────────────────────────────────────────────────
cmd_finish() {
  local run_id="${1:?run_id required}"
  local run_status="${2:?run_status required}"

  # Validate status
  case "$run_status" in
    completed|aborted|timeout|error) ;;
    *) echo "ERROR: invalid run_status '$run_status'. Use: completed|aborted|timeout|error" >&2; exit 1;;
  esac

  if ! _jq_available; then
    echo "WARNING: jq not available — finish telemetry skipped" >&2
    return 0
  fi

  local existing
  existing="$(_read_record "$run_id")"

  if [[ -z "$existing" ]]; then
    echo "ERROR: run_id '$run_id' not found in $AGENT_ACTUALS_LOG" >&2
    exit 1
  fi

  local now
  now="$(_now)"

  local updated
  updated="$(echo "$existing" | jq -c \
    --arg finished_at "$now" \
    --arg run_status  "$run_status" \
    '
    .finished_at = $finished_at |
    .run_status  = $run_status  |

    # Compute duration_s from started_at → finished_at (best-effort)
    .duration_s = (
      if .started_at then
        (($finished_at | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) -
         (.started_at  | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime))
      else null end
    ) |

    # Compute tools_unused = tools_available - keys(tools_invoked)
    .tools_unused = (
      if (.tools_available | length) > 0 then
        .tools_available - (.tools_invoked | keys)
      else [] end
    )
    ')"

  _upsert_record "$run_id" "$updated"
  echo "run_id=$run_id status=$run_status"
}

# ── Subcommand: annotate (optional enrichment) ───────────────────────────────
cmd_annotate() {
  # agent-run-logger.sh annotate <run_id> --tools-available tool1,tool2,...
  # agent-run-logger.sh annotate <run_id> --model model_id
  # agent-run-logger.sh annotate <run_id> --tokens-in N --tokens-out N --cost-usd N
  local run_id="${1:?run_id required}"; shift

  if ! _jq_available; then
    echo "WARNING: jq not available — annotate skipped" >&2
    return 0
  fi

  local existing
  existing="$(_read_record "$run_id")"
  [[ -z "$existing" ]] && { echo "ERROR: run_id '$run_id' not found" >&2; exit 1; }

  local updated="$existing"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tools-available)
        local tools_json
        tools_json="$(echo "${2:?}" | tr ',' '\n' | jq -Rc . | jq -sc .)"
        updated="$(echo "$updated" | jq -c --argjson tools "$tools_json" '.tools_available = $tools')"
        shift 2 ;;
      --model)
        updated="$(echo "$updated" | jq -c --arg m "${2:?}" '.models_used = (.models_used + [$m] | unique)')"
        shift 2 ;;
      --tokens-in)
        updated="$(echo "$updated" | jq -c --argjson n "${2:?}" '.tokens_in = $n')"
        shift 2 ;;
      --tokens-out)
        updated="$(echo "$updated" | jq -c --argjson n "${2:?}" '.tokens_out = $n')"
        shift 2 ;;
      --cost-usd)
        updated="$(echo "$updated" | jq -c --argjson n "${2:?}" '.cost_usd = $n')"
        shift 2 ;;
      *)
        echo "ERROR: unknown annotate flag '$1'" >&2; exit 1 ;;
    esac
  done

  _upsert_record "$run_id" "$updated"
}

# ── Dispatcher ───────────────────────────────────────────────────────────────
SUBCOMMAND="${1:-}"
shift || true

case "$SUBCOMMAND" in
  start)      cmd_start      "$@" ;;
  tool-call)  cmd_tool_call  "$@" ;;
  finish)     cmd_finish     "$@" ;;
  annotate)   cmd_annotate   "$@" ;;
  *)
    echo "Usage: agent-run-logger.sh <start|tool-call|finish|annotate> [args...]" >&2
    echo ""
    echo "  start     <agent> <task>                          → prints run_id"
    echo "  tool-call <run_id> <tool> <status>                → ok|error|skipped|blocked|timeout|aborted"
    echo "  finish    <run_id> <run_status>                   → completed|aborted|timeout|error"
    echo "  annotate  <run_id> [--tools-available t1,t2,...]"
    echo "                      [--model model_id]"
    echo "                      [--tokens-in N] [--tokens-out N] [--cost-usd N]"
    exit 1 ;;
esac
