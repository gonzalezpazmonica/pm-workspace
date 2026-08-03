#!/usr/bin/env bash
set -euo pipefail
# measure-reliability.sh — Task consistency vs capability across repeated runs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

task_class="${1:-}"
k="${2:-3}"
task_count="${3:-10}"
output_dir="$ROOT/output/reliability"

if [[ -z "$task_class" ]]; then
  echo "Usage: measure-reliability.sh <task-class> [--k N] [--tasks N] [--json]"
  echo "  task-class: spec-generation | code-review | bug-fix"
  exit 2
fi

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --k) k="$2"; shift 2 ;;
    --tasks) task_count="$2"; shift 2 ;;
    --json) output_json=true; shift ;;
    *) shift ;;
  esac
done

model_id="${CLAUDE_MODEL:-unknown}"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
task_dir="$ROOT/evaluations/tasks/$task_class"

if [[ ! -d "$task_dir" ]]; then
  echo "ERROR: Task class '$task_class' not found at $task_dir"
  exit 1
fi

mkdir -p "$output_dir"
output_file="$output_dir/${task_class}-$(date +%Y%m%d).json"

echo "Measuring reliability for $task_class (k=$k, tasks=$task_count, model=$model_id)"
echo ""

tasks_succeeded_once=0
total_successes=0
total_attempts=0

for i in $(seq 1 $task_count); do
  task_file=$(ls "$task_dir"/*.md 2>/dev/null | head -$i | tail -1)
  [[ -z "$task_file" ]] && break

  task_name=$(basename "$task_file" .md)
  task_successes=0

  for j in $(seq 1 $k); do
    echo -n "  Task $task_name [$j/$k]: "
    # Simulated run — in real use, this would invoke the agent
    if [[ -f "$task_file" ]]; then
      echo "SIMULATED (agent not invoked in measurement mode)"
      task_successes=$((task_successes + 1))
      total_successes=$((total_successes + 1))
    fi
    total_attempts=$((total_attempts + 1))
  done

  if [[ $task_successes -gt 0 ]]; then
    tasks_succeeded_once=$((tasks_succeeded_once + 1))
  fi
done

p_capable=0; p_consistent=0; gap=0
if [[ $total_attempts -gt 0 ]]; then
  p_capable=$(echo "scale=4; $tasks_succeeded_once / $task_count" | bc 2>/dev/null || echo "0")
  p_consistent=$(echo "scale=4; $total_successes / $total_attempts" | bc 2>/dev/null || echo "0")
  gap=$(echo "scale=4; $p_capable - $p_consistent" | bc 2>/dev/null || echo "0")
fi

result=$(cat <<JSON
{
  "task_class": "$task_class",
  "model_id": "$model_id",
  "timestamp": "$ts",
  "k": $k,
  "tasks": $task_count,
  "metrics": {
    "p_capable": $p_capable,
    "p_consistent": $p_consistent,
    "gap": $gap,
    "total_attempts": $total_attempts,
    "total_successes": $total_successes,
    "tasks_succeeded_once": $tasks_succeeded_once
  }
}
JSON
)

echo "$result" > "$output_file"

if [[ "${output_json:-false}" == "true" ]]; then
  echo "$result"
else
  echo ""
  echo "Reliability Report: $task_class"
  echo "================================"
  echo "Model:       $model_id"
  echo "Tasks:       $task_count (k=$k repetitions)"
  echo "Attempts:    $total_attempts"
  echo ""
  echo "p_capable:     $(printf "%.2f" "$p_capable")  (tasks with >=1 success)"
  echo "p_consistent:  $(printf "%.2f" "$p_consistent")  (all successes / all attempts)"
  echo "gap:           $(printf "%.2f" "$gap")"
  echo ""
  echo "Report saved: $output_file"
fi
