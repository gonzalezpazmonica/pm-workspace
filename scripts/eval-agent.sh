#!/usr/bin/env bash
set -uo pipefail
# eval-agent.sh — Agent Evaluation Runner (SPEC-036)
# Usage: bash scripts/eval-agent.sh {agent} [--compare {date}] [--list]

EVALS_DIR="tests/evals"
OUTPUT_DIR="output/evals"
DATE=$(date +%Y%m%d-%H%M%S)
REGRESSION_THRESHOLD=10

show_help() {
  echo "eval-agent.sh — Agent Evaluation Runner (SPEC-036)"
  echo "Usage: bash scripts/eval-agent.sh <agent> [--compare <date>] [--list] [--help]"
  echo "  <agent>            Run eval for agent"
  echo "  --compare <date>   Compare with previous evaluation"
  echo "  --list             List agents with golden sets"
}

list_agents() {
  echo "Agents with golden sets:"
  for dir in "$EVALS_DIR"/*/; do
    [ -d "$dir" ] || continue
    local agent; agent=$(basename "$dir")
    local ic; ic=$(find "$dir" -name 'input-*' 2>/dev/null | wc -l)
    local ec; ec=$(find "$dir" -name 'expected-*' 2>/dev/null | wc -l)
    echo "  $agent — $ic inputs, $ec expected"
  done
}

validate_agent() {
  local agent_dir="$EVALS_DIR/$1"
  if [ ! -d "$agent_dir" ]; then
    echo "ERROR: No golden set for '$1'"; list_agents; return 1
  fi
  local ic; ic=$(find "$agent_dir" -name 'input-*' 2>/dev/null | wc -l)
  [ "$ic" -gt 0 ] || { echo "ERROR: No inputs in $agent_dir"; return 1; }
}

count_pairs() { find "$EVALS_DIR/$1" -name 'input-*' 2>/dev/null | wc -l; }

get_previous_eval() {
  local d="$OUTPUT_DIR/$1"
  [ -d "$d" ] && ls -1 "$d"/*.yaml 2>/dev/null | sort -r | head -1
}

detect_regression() {
  local current="$1" previous="$2"
  [ -f "$previous" ] || { echo "NO_PREVIOUS"; return 0; }
  local cp; cp=$(grep 'precision:' "$current" 2>/dev/null | head -1 | awk '{print $2}')
  local pp; pp=$(grep 'precision:' "$previous" 2>/dev/null | head -1 | awk '{print $2}')
  [ -n "$cp" ] && [ -n "$pp" ] || { echo "INCOMPLETE_DATA"; return 0; }
  local ci; ci=$(echo "$cp" | awk '{printf "%d",$1*100}')
  local pi; pi=$(echo "$pp" | awk '{printf "%d",$1*100}')
  local drop=$((pi - ci))
  if [ "$drop" -gt "$REGRESSION_THRESHOLD" ]; then
    echo "REGRESSION:${pp}:${cp}:${drop}"; return 1
  fi
  echo "OK:${pp}:${cp}"
}

generate_template() {
  local agent="$1" pairs; pairs=$(count_pairs "$agent")
  local out="$OUTPUT_DIR/$agent/$DATE.yaml"
  mkdir -p "$OUTPUT_DIR/$agent"
  cat > "$out" <<YAML
# Agent Evaluation Result — SPEC-036
# Generated: $(date -Iseconds)
agent: $agent
date: "$DATE"
golden_set: "$EVALS_DIR/$agent/"
pairs_evaluated: $pairs
metrics:
  precision: 0.0
  recall: 0.0
  f1: 0.0
  false_positives: 0
  hallucinations: 0
  bias_score: 0.0
status: "template_generated"
evaluator: "pending"
comparison:
  vs_previous: "N/A"
YAML
  echo "$out"
}

main() {
  [ $# -eq 0 ] || [ "$1" = "--help" ] && { show_help; return 0; }
  [ "$1" = "--list" ] && { list_agents; return 0; }

  local agent="$1"; shift
  local compare_date=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --compare) compare_date="$2"; shift 2 ;;
      *) echo "Unknown: $1"; return 1 ;;
    esac
  done

  validate_agent "$agent" || return 1
  local out; out=$(generate_template "$agent")
  echo "Eval template: $out"
  echo "Golden set: $EVALS_DIR/$agent/ ($(count_pairs "$agent") pairs)"

  if [ -n "$compare_date" ]; then
    local pf="$OUTPUT_DIR/$agent/${compare_date}.yaml"
    [ -f "$pf" ] && { echo "Comparing: $pf"; detect_regression "$out" "$pf"; } \
                  || echo "WARNING: No eval at $pf"
  else
    local pf; pf=$(get_previous_eval "$agent")
    [ -n "$pf" ] && [ -f "$pf" ] && echo "Previous: $pf (use --compare)"
  fi
  echo "Next: Claude evaluates agent against golden sets and fills $out"
}

main "$@"
