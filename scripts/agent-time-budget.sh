#!/usr/bin/env bash
# agent-time-budget.sh — SE-217 Slice 2: time-budgeted command runner
# Ref: docs/propuestas/SE-217-autoresearch-patterns.md
# Note: --budget is in seconds (spec says minutes; using seconds for testability)
set -uo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_LOG="${SCRIPT_DIR}/agent-run-log.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") <subcommand> [options]

Subcommands:
  run      --budget N [--run-id X] [--task T] --cmd "CMD" [--score-cmd "SCORE_CMD"]
           Run CMD with a time budget of N seconds.
           --budget 0  disables timeout.
           --budget <negative>  is an error.
           Outputs:
             BUDGET_STATUS: completed | timeout | crash
             ELAPSED_S: <n>
             SCORE: <value>  (empty if no --score-cmd)

  report   --run-id X
           Print budget summary for a run (delegates to agent-run-log summary).

Ref: docs/propuestas/SE-217-autoresearch-patterns.md
EOF
  exit 1
}

# ── Subcommand: run ──────────────────────────────────────────────────────────
cmd_run() {
  local budget="" run_id="" task="" cmd="" score_cmd=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --budget)    budget="$2";    shift 2 ;;
      --run-id)    run_id="$2";    shift 2 ;;
      --task)      task="$2";      shift 2 ;;
      --cmd)       cmd="$2";       shift 2 ;;
      --score-cmd) score_cmd="$2"; shift 2 ;;
      *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  # Validate required args
  [[ -z "$budget" ]] && { echo "ERROR: --budget is required" >&2; exit 1; }
  [[ -z "$cmd" ]]    && { echo "ERROR: --cmd is required" >&2; exit 1; }

  # Validate budget is a non-negative integer
  if ! [[ "$budget" =~ ^-?[0-9]+$ ]]; then
    echo "ERROR: --budget must be an integer, got: ${budget}" >&2
    exit 1
  fi
  if [[ "$budget" -lt 0 ]]; then
    echo "ERROR: --budget must be >= 0, got: ${budget}" >&2
    exit 1
  fi

  # ── Execute with time tracking ────────────────────────────────────────────
  local start_s exit_code budget_status
  start_s=$(date +%s)
  budget_status="completed"

  if [[ "$budget" -eq 0 ]]; then
    # No timeout — run until completion
    set +e
    eval "$cmd"
    exit_code=$?
    set -e
  else
    # Run with timeout (budget seconds)
    set +e
    timeout "$budget" bash -c "$cmd"
    exit_code=$?
    set -e
    # timeout exits with 124 on SIGTERM
    if [[ $exit_code -eq 124 ]]; then
      budget_status="timeout"
    fi
  fi

  local end_s elapsed_s
  end_s=$(date +%s)
  elapsed_s=$(( end_s - start_s ))
  [[ $elapsed_s -lt 0 ]] && elapsed_s=0

  # Determine status (timeout already set above if applicable)
  if [[ "$budget_status" != "timeout" ]]; then
    if [[ $exit_code -ne 0 ]]; then
      budget_status="crash"
    else
      budget_status="completed"
    fi
  fi

  # ── Score capture ─────────────────────────────────────────────────────────
  local score=""
  if [[ -n "$score_cmd" && "$budget_status" == "completed" ]]; then
    set +e
    score=$(eval "$score_cmd" 2>/dev/null)
    set -e
  fi

  # ── Register in agent-run-log if --run-id and --task present ─────────────
  if [[ -n "$run_id" && -n "$task" && -f "$RUN_LOG" ]]; then
    case "$budget_status" in
      completed)
        bash "$RUN_LOG" keep \
          --run-id "$run_id" \
          --task "$task" \
          --score "${score:-}" \
          --description "time-budget completed in ${elapsed_s}s" \
          2>/dev/null || true
        ;;
      timeout)
        bash "$RUN_LOG" discard \
          --run-id "$run_id" \
          --task "$task" \
          --reason "timeout after ${elapsed_s}s (budget=${budget}s)" \
          2>/dev/null || true
        ;;
      crash)
        bash "$RUN_LOG" crash \
          --run-id "$run_id" \
          --task "$task" \
          --error "cmd exited with code ${exit_code} after ${elapsed_s}s" \
          2>/dev/null || true
        ;;
    esac
  fi

  # ── Output ────────────────────────────────────────────────────────────────
  echo "BUDGET_STATUS: ${budget_status}"
  echo "ELAPSED_S: ${elapsed_s}"
  echo "SCORE: ${score}"
}

# ── Subcommand: report ───────────────────────────────────────────────────────
cmd_report() {
  local run_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-id) run_id="$2"; shift 2 ;;
      *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  [[ -z "$run_id" ]] && { echo "ERROR: --run-id is required" >&2; exit 1; }

  if [[ -f "$RUN_LOG" ]]; then
    bash "$RUN_LOG" summary --run-id "$run_id"
  else
    echo "ERROR: agent-run-log.sh not found at ${RUN_LOG}" >&2
    exit 1
  fi
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
subcmd="${1:-help}"; shift || true
case "$subcmd" in
  run)    cmd_run    "$@" ;;
  report) cmd_report "$@" ;;
  help|*) usage ;;
esac
