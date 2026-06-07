#!/bin/bash
# run-agent-evals.sh — SE-204: evaluation harness for critical agents
# Ref: docs/propuestas/SE-204-eval-harness.md
# Validates eval case STRUCTURE (Slice 1-2). LLM invocation is SE-204 Slice 3-4.
set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
EVALS_DIR="${PROJECT_ROOT:-$(pwd)}/tests/evals"
OUTPUT_DIR="${PROJECT_ROOT:-$(pwd)}/output"
THRESHOLD="${SAVIA_EVAL_THRESHOLD:-80}"
DATE="$(date +%Y%m%d)"
REPORT_FILE="${OUTPUT_DIR}/eval-report-${DATE}.md"

# Agents covered by this harness
KNOWN_AGENTS=(sdd-spec-writer court-orchestrator business-analyst)

# Minimum structural requirements
MIN_CRITERIA_COUNT=5   # criteria.md must have >= 5 checklist items
MIN_INPUT_WORDS=50     # input.md must have >= 50 words

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
AGENT_FILTER="all"
DRY_RUN=false
LIST_ONLY=false

_usage() {
  cat <<EOF
Usage: run-agent-evals.sh [OPTIONS]

Options:
  --agent <name>   Run evals only for the specified agent
  --dry-run        Show what would be evaluated without executing
  --list           List all available eval cases
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      shift
      AGENT_FILTER="${1:-}"
      [[ -z "$AGENT_FILTER" ]] && { echo "ERROR: --agent requires a name" >&2; exit 1; }
      ;;
    --dry-run)   DRY_RUN=true ;;
    --list)      LIST_ONLY=true ;;
    -h|--help)   _usage; exit 0 ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      _usage >&2
      exit 1
      ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------

# Count checklist items (lines starting with "- [ ]" or "- [x]") in a file
_count_criteria() {
  local file="$1"
  grep -c '^\- \[' "$file" 2>/dev/null || echo 0
}

# Count words in a file
_count_words() {
  local file="$1"
  wc -w < "$file" 2>/dev/null || echo 0
}

# Check if a single eval case directory is structurally valid
# Returns 0 (valid) or 1 (invalid), prints reason to stdout
_validate_eval_case() {
  local case_dir="$1"
  local input="${case_dir}/input.md"
  local criteria="${case_dir}/criteria.md"
  local issues=()

  [[ -f "$input" ]]    || issues+=("input.md missing")
  [[ -f "$criteria" ]] || issues+=("criteria.md missing")

  if [[ -f "$input" ]]; then
    local wc
    wc="$(_count_words "$input")"
    (( wc >= MIN_INPUT_WORDS )) || issues+=("input.md has ${wc} words (need >= ${MIN_INPUT_WORDS})")
  fi

  if [[ -f "$criteria" ]]; then
    local cc
    cc="$(_count_criteria "$criteria")"
    (( cc >= MIN_CRITERIA_COUNT )) || issues+=("criteria.md has ${cc} criteria (need >= ${MIN_CRITERIA_COUNT})")
  fi

  if (( ${#issues[@]} == 0 )); then
    echo "PASS"
    return 0
  else
    echo "FAIL: $(IFS='; '; echo "${issues[*]}")"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# List mode
# ---------------------------------------------------------------------------
if [[ "$LIST_ONLY" == "true" ]]; then
  echo "Available eval cases in ${EVALS_DIR}:"
  echo ""
  for agent_dir in "${EVALS_DIR}"/*/; do
    [[ -d "$agent_dir" ]] || continue
    agent="$(basename "$agent_dir")"
    # Count eval cases with a loop (SC2144: -d doesn't work with globs)
    case_count=0
    for d in "${agent_dir}"eval-*/; do [[ -d "$d" ]] && case_count=$((case_count+1)); done
    [[ "$case_count" -eq 0 ]] && continue
    echo "  Agent: ${agent}"
    for case_dir in "${agent_dir}"eval-*/; do
      [[ -d "$case_dir" ]] || continue
      echo "    - $(basename "$case_dir")"
    done
  done
  exit 0
fi

# ---------------------------------------------------------------------------
# Dry-run mode
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[dry-run] Would evaluate the following cases:"
  for agent in "${KNOWN_AGENTS[@]}"; do
    [[ "$AGENT_FILTER" != "all" && "$AGENT_FILTER" != "$agent" ]] && continue
    agent_dir="${EVALS_DIR}/${agent}"
    [[ -d "$agent_dir" ]] || continue
    for case_dir in "${agent_dir}"/eval-*/; do
      [[ -d "$case_dir" ]] || continue
      echo "  ${agent}/$(basename "$case_dir")"
    done
  done
  exit 0
fi

# ---------------------------------------------------------------------------
# Main evaluation loop
# ---------------------------------------------------------------------------
mkdir -p "$OUTPUT_DIR"

total_cases=0
passed_cases=0

# Per-agent tracking
declare -A agent_total
declare -A agent_passed
declare -A agent_results

for agent in "${KNOWN_AGENTS[@]}"; do
  agent_total[$agent]=0
  agent_passed[$agent]=0
  agent_results[$agent]=""
done

for agent in "${KNOWN_AGENTS[@]}"; do
  [[ "$AGENT_FILTER" != "all" && "$AGENT_FILTER" != "$agent" ]] && continue

  agent_dir="${EVALS_DIR}/${agent}"
  if [[ ! -d "$agent_dir" ]]; then
    echo "WARN: Agent directory not found: ${agent_dir}" >&2
    continue
  fi

  for case_dir in "${agent_dir}"/eval-*/; do
    [[ -d "$case_dir" ]] || continue
    case_name="$(basename "$case_dir")"

    result="$(_validate_eval_case "$case_dir")"
    rc=$?

    (( total_cases++ ))
    (( agent_total[$agent]++ ))

    if (( rc == 0 )); then
      (( passed_cases++ ))
      (( agent_passed[$agent]++ ))
      agent_results[$agent]+="| ${case_name} | PASS | — |\n"
    else
      agent_results[$agent]+="| ${case_name} | FAIL | ${result#FAIL: } |\n"
    fi
  done
done

# ---------------------------------------------------------------------------
# Score calculation
# ---------------------------------------------------------------------------
if (( total_cases == 0 )); then
  echo "ERROR: No eval cases found. Check EVALS_DIR=${EVALS_DIR}" >&2
  exit 1
fi

# Use integer arithmetic (multiply by 100, then divide)
score=$(( (passed_cases * 100) / total_cases ))

# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------
{
  echo "# Eval Report — ${DATE}"
  echo ""
  echo "> SE-204: Evaluation harness structural validation"
  echo "> Agent filter: ${AGENT_FILTER}"
  echo "> Threshold: ${THRESHOLD}%"
  echo ""
  echo "## Summary"
  echo ""
  echo "| Metric | Value |"
  echo "|---|---|"
  echo "| Total eval cases | ${total_cases} |"
  echo "| Passed | ${passed_cases} |"
  echo "| Failed | $(( total_cases - passed_cases )) |"
  echo "| Score | ${score}% |"
  echo "| Threshold | ${THRESHOLD}% |"
  echo "| Result | $([ "$score" -ge "$THRESHOLD" ] && echo PASS || echo FAIL) |"
  echo ""
  echo "## Results by Agent"
  echo ""

  for agent in "${KNOWN_AGENTS[@]}"; do
    [[ "$AGENT_FILTER" != "all" && "$AGENT_FILTER" != "$agent" ]] && continue
    [[ "${agent_total[$agent]:-0}" -eq 0 ]] && continue

    agent_score=0
    [[ "${agent_total[$agent]}" -gt 0 ]] && \
      agent_score=$(( (agent_passed[$agent] * 100) / agent_total[$agent] ))

    echo "### ${agent}"
    echo ""
    echo "Score: ${agent_passed[$agent]}/${agent_total[$agent]} (${agent_score}%)"
    echo ""
    echo "| Eval Case | Status | Issues |"
    echo "|---|---|---|"
    printf "%b" "${agent_results[$agent]}"
    echo ""
  done

  echo "## Note"
  echo ""
  echo "This report validates STRUCTURE only (SE-204 Slice 1-2)."
  echo "LLM-as-judge execution is SE-204 Slice 3-4."
} > "$REPORT_FILE"

# ---------------------------------------------------------------------------
# Output summary to stdout
# ---------------------------------------------------------------------------
echo "Eval harness complete."
echo "  Cases:  ${passed_cases}/${total_cases} passed"
echo "  Score:  ${score}%  (threshold: ${THRESHOLD}%)"
echo "  Report: ${REPORT_FILE}"

if (( score < THRESHOLD )); then
  echo "FAIL: Score ${score}% is below threshold ${THRESHOLD}%" >&2
  exit 1
fi

exit 0
