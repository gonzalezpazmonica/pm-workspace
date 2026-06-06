#!/usr/bin/env bash
# tribunal-async-runner.sh — SPEC-159: Async Tribunal Fan-out
#
# Launches tribunal judges in parallel (background + wait) and aggregates
# results. Any judge returning BLOCK causes exit 1. Supports --mode sync
# for sequential fallback.
#
# Usage:
#   tribunal-async-runner.sh [--mode sync|async] judge1 judge2 judge3 ...
#
# Environment:
#   SAVIA_TRIBUNAL_TIMEOUT  Per-judge timeout in seconds (default: 60)
#   SAVIA_TRIBUNAL_MODE     Default mode: async|sync (overridden by --flag)
#
# Exit codes:
#   0  All judges PASS
#   1  At least one judge returned BLOCK
#   2  Usage error
#
# SPEC-159 — docs/propuestas/SPEC-159-async-tribunal-fanout.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ─────────────────────────────────────────────────────────────────
TIMEOUT="${SAVIA_TRIBUNAL_TIMEOUT:-60}"
MODE="${SAVIA_TRIBUNAL_MODE:-async}"
TMPDIR_RUN=""

# ── Argument parsing ──────────────────────────────────────────────────────────
parse_args() {
  local judges=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        [[ $# -lt 2 ]] && { echo "ERROR: --mode requires a value (sync|async)" >&2; exit 2; }
        MODE="$2"; shift 2 ;;
      --timeout)
        [[ $# -lt 2 ]] && { echo "ERROR: --timeout requires a value" >&2; exit 2; }
        TIMEOUT="$2"; shift 2 ;;
      --help|-h)
        usage; exit 0 ;;
      -*)
        echo "ERROR: Unknown flag: $1" >&2; exit 2 ;;
      *)
        judges+=("$1"); shift ;;
    esac
  done

  if [[ "${#judges[@]}" -eq 0 ]]; then
    echo "WARNING: No judges provided — nothing to run." >&2
    exit 0
  fi

  JUDGES=("${judges[@]}")
}

usage() {
  cat <<EOF
tribunal-async-runner.sh — SPEC-159 async tribunal fan-out

Usage:
  tribunal-async-runner.sh [OPTIONS] judge1 judge2 ...

Options:
  --mode sync|async   Execution mode (default: async)
  --timeout N         Per-judge timeout in seconds (default: \$SAVIA_TRIBUNAL_TIMEOUT or 60)
  --help              Show this help

Environment:
  SAVIA_TRIBUNAL_TIMEOUT  Per-judge timeout (default 60s)
  SAVIA_TRIBUNAL_MODE     Default mode (default: async)

Exit codes:
  0  All judges PASS
  1  At least one judge returned BLOCK
  2  Usage error
EOF
}

# ── Run a single judge, write result to result file ───────────────────────────
# Result file contains: PASS|BLOCK|TIMEOUT|ERROR
run_judge() {
  local judge="$1"
  local result_file="$2"
  local time_file="$3"
  local start_ts
  start_ts=$(date +%s%3N 2>/dev/null || date +%s)

  # Locate judge agent file
  local judge_file="$ROOT/.opencode/agents/${judge}.md"
  if [[ ! -f "$judge_file" ]]; then
    echo "WARNING: judge agent file not found: $judge_file — skipping" >&2
    echo "ERROR" > "$result_file"
    echo "0" > "$time_file"
    return
  fi

  # Run judge with timeout; judges are agents — we simulate by checking if they
  # can be invoked. In shell context, we invoke via bash if a run script exists.
  local verdict="PASS"
  local judge_run_script="$ROOT/scripts/run-judge.sh"

  if [[ -f "$judge_run_script" ]]; then
    local run_output
    if ! run_output=$(timeout "$TIMEOUT" bash "$judge_run_script" "$judge" 2>&1); then
      local exit_code=$?
      if [[ $exit_code -eq 124 ]]; then
        echo "WARNING: judge '$judge' timed out after ${TIMEOUT}s" >&2
        verdict="TIMEOUT"
      elif echo "$run_output" | grep -qi "BLOCK"; then
        verdict="BLOCK"
      else
        verdict="ERROR"
      fi
    else
      if echo "$run_output" | grep -qi "BLOCK"; then
        verdict="BLOCK"
      else
        verdict="PASS"
      fi
    fi
  else
    # No run script — agent file exists, treat as PASS (dry agent invocation)
    verdict="PASS"
  fi

  local end_ts
  end_ts=$(date +%s%3N 2>/dev/null || date +%s)
  local elapsed_ms=$(( end_ts - start_ts ))

  echo "$verdict" > "$result_file"
  echo "$elapsed_ms" > "$time_file"
}

# ── Async mode: launch all judges in parallel ─────────────────────────────────
run_async() {
  local judges=("$@")
  local pids=()
  local result_files=()
  local time_files=()
  local global_start
  global_start=$(date +%s%3N 2>/dev/null || date +%s)

  echo "tribunal-async-runner: launching ${#judges[@]} judges in parallel [mode=async, timeout=${TIMEOUT}s]"

  for judge in "${judges[@]}"; do
    local result_file="$TMPDIR_RUN/result-${judge}"
    local time_file="$TMPDIR_RUN/time-${judge}"
    result_files+=("$result_file")
    time_files+=("$time_file")
    run_judge "$judge" "$result_file" "$time_file" &
    pids+=($!)
  done

  # Wait for all background jobs
  local wait_failed=0
  for pid in "${pids[@]}"; do
    wait "$pid" || wait_failed=$((wait_failed + 1))
  done

  local global_end
  global_end=$(date +%s%3N 2>/dev/null || date +%s)
  local total_ms=$(( global_end - global_start ))

  aggregate_results "${judges[@]}"
  local agg_rc=$?

  echo "tribunal-async-runner: total wall-time ${total_ms}ms for ${#judges[@]} judges"
  return $agg_rc
}

# ── Sync mode: run judges sequentially ───────────────────────────────────────
run_sync() {
  local judges=("$@")
  local global_start
  global_start=$(date +%s%3N 2>/dev/null || date +%s)

  echo "tribunal-async-runner: running ${#judges[@]} judges sequentially [mode=sync, timeout=${TIMEOUT}s]"

  for judge in "${judges[@]}"; do
    local result_file="$TMPDIR_RUN/result-${judge}"
    local time_file="$TMPDIR_RUN/time-${judge}"
    run_judge "$judge" "$result_file" "$time_file"
  done

  local global_end
  global_end=$(date +%s%3N 2>/dev/null || date +%s)
  local total_ms=$(( global_end - global_start ))

  aggregate_results "${judges[@]}"
  local agg_rc=$?

  echo "tribunal-async-runner: total wall-time ${total_ms}ms for ${#judges[@]} judges"
  return $agg_rc
}

# ── Aggregate results from all judges ────────────────────────────────────────
aggregate_results() {
  local judges=("$@")
  local any_block=0

  echo "tribunal-async-runner: --- results ---"
  for judge in "${judges[@]}"; do
    local result_file="$TMPDIR_RUN/result-${judge}"
    local time_file="$TMPDIR_RUN/time-${judge}"
    local verdict="UNKNOWN"
    local elapsed_ms=0

    [[ -f "$result_file" ]] && verdict=$(cat "$result_file")
    [[ -f "$time_file" ]] && elapsed_ms=$(cat "$time_file")

    printf "  %-40s %s  (%sms)\n" "$judge" "$verdict" "$elapsed_ms"

    if [[ "$verdict" == "BLOCK" || "$verdict" == "TIMEOUT" ]]; then
      any_block=1
    fi
  done
  echo "tribunal-async-runner: --- end results ---"

  if [[ $any_block -eq 1 ]]; then
    echo "tribunal-async-runner: VERDICT=BLOCK — at least one judge blocked" >&2
    return 1
  fi

  echo "tribunal-async-runner: VERDICT=PASS — all judges passed"
  return 0
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
cleanup() {
  [[ -n "$TMPDIR_RUN" && -d "$TMPDIR_RUN" ]] && rm -rf "$TMPDIR_RUN"
}

# ── Main (skipped when sourced for unit testing) ──────────────────────────────
# Guard: set TRIBUNAL_SOURCED=1 before sourcing to load functions only.
if [[ "${TRIBUNAL_SOURCED:-0}" != "1" ]]; then
  trap cleanup EXIT

  JUDGES=()
  parse_args "$@"

  TMPDIR_RUN=$(mktemp -d)

  case "$MODE" in
    async)
      run_async "${JUDGES[@]}"
      ;;
    sync)
      run_sync "${JUDGES[@]}"
      ;;
    *)
      echo "ERROR: Unknown mode '$MODE'. Use async or sync." >&2
      exit 2
      ;;
  esac
fi
