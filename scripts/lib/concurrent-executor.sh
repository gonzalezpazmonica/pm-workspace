#!/usr/bin/env bash
# concurrent-executor.sh — Semaphore-bounded parallel task execution
#
# Learned from multica-ai/multica: bounded concurrency with graceful drain
# on shutdown. Used by overnight-sprint and dag-execute for parallel agent
# dispatch without overwhelming the system.
#
# Usage (source this, don't execute):
#   source scripts/lib/concurrent-executor.sh
#   executor_init 5        # max 5 concurrent tasks
#   executor_submit "task-name" "bash some-script.sh"
#   executor_submit "task-2" "bash another.sh"
#   executor_drain 30      # wait up to 30s for all tasks to finish

EXECUTOR_MAX="${EXECUTOR_MAX:-5}"
EXECUTOR_PIDS=()
EXECUTOR_NAMES=()
EXECUTOR_RUNNING=0

executor_init() {
  EXECUTOR_MAX="${1:-5}"
  EXECUTOR_PIDS=()
  EXECUTOR_NAMES=()
  EXECUTOR_RUNNING=0
  trap 'executor_drain 30' EXIT
}

executor_submit() {
  local name="$1"; shift
  local cmd="$*"

  # Wait for a slot if at max concurrency
  while [[ "$EXECUTOR_RUNNING" -ge "$EXECUTOR_MAX" ]]; do
    _executor_reap
    [[ "$EXECUTOR_RUNNING" -ge "$EXECUTOR_MAX" ]] && sleep 1
  done

  # Launch in background
  eval "$cmd" &
  local pid=$!
  EXECUTOR_PIDS+=("$pid")
  EXECUTOR_NAMES+=("$name")
  ((EXECUTOR_RUNNING++))
  echo "LAUNCHED: $name (pid $pid, $EXECUTOR_RUNNING/$EXECUTOR_MAX slots)"
}

executor_drain() {
  local timeout="${1:-30}"
  local deadline=$((SECONDS + timeout))
  echo "DRAINING: $EXECUTOR_RUNNING tasks, ${timeout}s timeout"

  while [[ "$EXECUTOR_RUNNING" -gt 0 && "$SECONDS" -lt "$deadline" ]]; do
    _executor_reap
    [[ "$EXECUTOR_RUNNING" -gt 0 ]] && sleep 1
  done

  if [[ "$EXECUTOR_RUNNING" -gt 0 ]]; then
    echo "TIMEOUT: $EXECUTOR_RUNNING tasks still running after ${timeout}s"
    for i in "${!EXECUTOR_PIDS[@]}"; do
      if kill -0 "${EXECUTOR_PIDS[$i]}" 2>/dev/null; then
        echo "  KILLING: ${EXECUTOR_NAMES[$i]} (pid ${EXECUTOR_PIDS[$i]})"
        kill "${EXECUTOR_PIDS[$i]}" 2>/dev/null || true
      fi
    done
  else
    echo "DRAINED: all tasks completed"
  fi
}

_executor_reap() {
  for i in "${!EXECUTOR_PIDS[@]}"; do
    if ! kill -0 "${EXECUTOR_PIDS[$i]}" 2>/dev/null; then
      wait "${EXECUTOR_PIDS[$i]}" 2>/dev/null
      local rc=$?
      local status="OK"
      [[ $rc -ne 0 ]] && status="FAIL(exit $rc)"
      echo "FINISHED: ${EXECUTOR_NAMES[$i]} — $status"
      unset 'EXECUTOR_PIDS[$i]'
      unset 'EXECUTOR_NAMES[$i]'
      ((EXECUTOR_RUNNING--))
    fi
  done
  # Re-index arrays
  EXECUTOR_PIDS=("${EXECUTOR_PIDS[@]}")
  EXECUTOR_NAMES=("${EXECUTOR_NAMES[@]}")
}
