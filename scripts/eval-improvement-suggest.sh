#!/bin/bash
# eval-improvement-suggest.sh — SE-215: generate skill improvement proposals from eval reports
# Ref: docs/propuestas/SE-215-eval-driven-improvement-loop.md
set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
OUTPUT_DIR="${PROJECT_ROOT:-$(pwd)}/output"
DEFAULT_THRESHOLD=80
DATE="$(date +%Y%m%d)"
PROPOSALS_FILE="${OUTPUT_DIR}/eval-improvement-proposals-${DATE}.md"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
REPORT_FILE=""
DRY_RUN=false
THRESHOLD=$DEFAULT_THRESHOLD
SINCE_DATE=""
JSON_OUTPUT=false

_usage() {
  cat <<EOF
Usage: eval-improvement-suggest.sh [OPTIONS]

Reads an eval report and generates improvement proposals for failing cases.

Options:
  --report <file>      Use this report file (default: latest output/eval-report-*.md)
  --dry-run            Print proposals without creating output file
  --threshold <N>      Score threshold (default: ${DEFAULT_THRESHOLD})
  --since <YYYY-MM-DD> Only process reports from this date or later
  --json               Output as JSON array
  -h, --help           Show this help

Exit codes:
  0  Always — this script only proposes, never blocks (SE-215 AC6)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)
      shift
      REPORT_FILE="${1:-}"
      [[ -z "$REPORT_FILE" ]] && { echo "ERROR: --report requires a file path" >&2; exit 0; }
      ;;
    --dry-run)    DRY_RUN=true ;;
    --threshold)
      shift
      THRESHOLD="${1:-$DEFAULT_THRESHOLD}"
      if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --threshold requires an integer" >&2
        exit 0
      fi
      ;;
    --since)
      shift
      SINCE_DATE="${1:-}"
      [[ -z "$SINCE_DATE" ]] && { echo "ERROR: --since requires a date (YYYY-MM-DD)" >&2; exit 0; }
      ;;
    --json)       JSON_OUTPUT=true ;;
    -h|--help)    _usage; exit 0 ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      _usage >&2
      exit 0
      ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Resolve report file
# ---------------------------------------------------------------------------
_find_latest_report() {
  local output_dir="$1"
  local since="$2"
  local latest=""

  for f in "${output_dir}"/eval-report-*.md; do
    [[ -f "$f" ]] || continue
    # Extract date from filename: eval-report-YYYYMMDD.md
    local fname
    fname="$(basename "$f")"
    local fdate
    fdate="${fname#eval-report-}"
    fdate="${fdate%.md}"
    # Apply --since filter if set
    if [[ -n "$since" ]]; then
      local since_compact
      since_compact="${since//-/}"
      [[ "$fdate" < "$since_compact" ]] && continue
    fi
    # Track latest by lexicographic date comparison
    if [[ -z "$latest" || "$fdate" > "$(basename "$latest" | sed 's/eval-report-//;s/\.md//')" ]]; then
      latest="$f"
    fi
  done

  echo "$latest"
}

if [[ -z "$REPORT_FILE" ]]; then
  REPORT_FILE="$(_find_latest_report "$OUTPUT_DIR" "$SINCE_DATE")"
  if [[ -z "$REPORT_FILE" ]]; then
    echo "INFO: No eval reports found in ${OUTPUT_DIR}. Nothing to propose." >&2
    exit 0
  fi
fi

if [[ ! -f "$REPORT_FILE" ]]; then
  echo "INFO: Report file not found: ${REPORT_FILE}. Nothing to propose." >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Parse report: extract FAIL cases with agent/score info
# ---------------------------------------------------------------------------
# Report format (from run-agent-evals.sh):
#   ### {agent_name}
#   Score: N/M (P%)
#   | {eval_case} | PASS/FAIL | {issues} |
#
# We also use the per-agent score line to compute the score percentage for
# structural reports. For individual case scores, we derive from status:
#   PASS = 100, FAIL = 0 (structural harness — no numeric case scores yet)

declare -a FAILING_CASES=()
declare -a FAILING_AGENTS=()
declare -a FAILING_SCORES=()
declare -a FAILING_ISSUES=()

current_agent=""

while IFS= read -r line; do
  # Detect agent section header: "### agent-name"
  if [[ "$line" =~ ^###[[:space:]]+(.+)$ ]]; then
    current_agent="${BASH_REMATCH[1]}"
    continue
  fi

  # Detect table row: "| eval-case | FAIL | ... |"
  if [[ -n "$current_agent" && "$line" =~ ^\|[[:space:]]*([^|]+)[[:space:]]*\|[[:space:]]*FAIL[[:space:]]*\|[[:space:]]*([^|]*)[[:space:]]*\| ]]; then
    local_case="$(echo "${BASH_REMATCH[1]}" | xargs)"
    local_issues="$(echo "${BASH_REMATCH[2]}" | xargs)"
    # Structural harness: FAIL = 0 score
    FAILING_CASES+=("$local_case")
    FAILING_AGENTS+=("$current_agent")
    FAILING_SCORES+=(0)
    FAILING_ISSUES+=("$local_issues")
    continue
  fi

  # Detect agent score line to capture per-agent percentage for threshold comparison
  # "Score: N/M (P%)" — if P% < threshold, flag the PASS cases too? No: spec says per-case.
  # Per spec: "for each eval case that fails (score < threshold)". Structural FAIL = score 0.
  # PASS cases from structural harness = score 100 (never triggers threshold).
done < "$REPORT_FILE"

total_failing=${#FAILING_CASES[@]}

if (( total_failing == 0 )); then
  echo "INFO: No failing eval cases found in ${REPORT_FILE}. No proposals generated." >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Generate proposals
# ---------------------------------------------------------------------------
_build_proposal_md() {
  local agent="$1"
  local eval_case="$2"
  local score="$3"
  local issues="$4"

  local suggestion="Review ${agent}.md system prompt for edge cases related to ${eval_case}"
  [[ -n "$issues" && "$issues" != "—" ]] && suggestion="${suggestion}. Issues: ${issues}"

  cat <<PROPOSAL

## Proposal: improve ${agent}/${eval_case}

- **Agent**: ${agent}
- **Eval case**: ${eval_case}
- **Score**: ${score}/100 (threshold: ${THRESHOLD})
- **Suggestion**: ${suggestion}
- **Files to check**: [.opencode/agents/${agent}.md, tests/evals/${agent}/${eval_case}/criteria.md]
- **Action**: Run \`bash scripts/run-agent-evals.sh --agent ${agent}\` after changes
PROPOSAL
}

_build_proposal_json() {
  local agent="$1"
  local eval_case="$2"
  local score="$3"
  local issues="$4"

  local suggestion="Review ${agent}.md system prompt for edge cases related to ${eval_case}"
  [[ -n "$issues" && "$issues" != "—" ]] && suggestion="${suggestion}. Issues: ${issues}"

  # Escape double quotes in fields
  local esc_suggestion="${suggestion//\"/\\\"}"
  local esc_issues="${issues//\"/\\\"}"

  cat <<JSON
  {
    "agent": "${agent}",
    "eval_case": "${eval_case}",
    "score": ${score},
    "threshold": ${THRESHOLD},
    "suggestion": "${esc_suggestion}",
    "files_to_check": [
      ".opencode/agents/${agent}.md",
      "tests/evals/${agent}/${eval_case}/criteria.md"
    ],
    "action": "bash scripts/run-agent-evals.sh --agent ${agent}"
  }
JSON
}

# ---------------------------------------------------------------------------
# Build output
# ---------------------------------------------------------------------------
if [[ "$JSON_OUTPUT" == "true" ]]; then
  json_items=()
  for i in "${!FAILING_CASES[@]}"; do
    json_items+=("$(_build_proposal_json "${FAILING_AGENTS[$i]}" "${FAILING_CASES[$i]}" "${FAILING_SCORES[$i]}" "${FAILING_ISSUES[$i]}")")
  done

  output_json="[\n"
  for i in "${!json_items[@]}"; do
    output_json+="${json_items[$i]}"
    (( i < ${#json_items[@]} - 1 )) && output_json+=","
    output_json+="\n"
  done
  output_json+="]"

  if [[ "$DRY_RUN" == "true" ]]; then
    printf "%b" "$output_json"
  else
    mkdir -p "$OUTPUT_DIR"
    printf "%b" "$output_json" > "$PROPOSALS_FILE"
    echo "Proposals written to: ${PROPOSALS_FILE}" >&2
  fi
  exit 0
fi

# Markdown output
output_md="# Eval Improvement Proposals — ${DATE}

> SE-215: Auto-generated from ${REPORT_FILE}
> Threshold: ${THRESHOLD}
> Failing cases: ${total_failing}
> Source of truth: docs/propuestas/SE-215-eval-driven-improvement-loop.md
"

for i in "${!FAILING_CASES[@]}"; do
  output_md+="$(_build_proposal_md "${FAILING_AGENTS[$i]}" "${FAILING_CASES[$i]}" "${FAILING_SCORES[$i]}" "${FAILING_ISSUES[$i]}")"
done

if [[ "$DRY_RUN" == "true" ]]; then
  printf "%s\n" "$output_md"
  echo ""
  echo "[dry-run] Would write to: ${PROPOSALS_FILE}" >&2
else
  mkdir -p "$OUTPUT_DIR"
  printf "%s\n" "$output_md" > "$PROPOSALS_FILE"
  echo "Proposals written to: ${PROPOSALS_FILE}" >&2
fi

exit 0
