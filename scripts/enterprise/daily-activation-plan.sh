#!/usr/bin/env bash
# daily-activation-plan.sh — SE-034 Agent Activation Plan
set -uo pipefail
# Generates the daily agent activation plan for a session.
#
# Usage:
#   scripts/enterprise/daily-activation-plan.sh [--date YYYY-MM-DD] [--budget-tokens N]
#
# Reads:  output/router-decisions.jsonl  (agents used recently)
#         ROADMAP.md                      (backlog/pending tasks)
#         data/agent-actuals.jsonl        (real timing data if available)
# Output: output/activation-plans/YYYY-MM-DD.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

PLAN_DATE="$(date +%Y-%m-%d)"
BUDGET_TOKENS=200000

# ── arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)          PLAN_DATE="$2"; shift 2 ;;
    --budget-tokens) BUDGET_TOKENS="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: daily-activation-plan.sh [--date YYYY-MM-DD] [--budget-tokens N]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

OUTPUT_DIR="${REPO_ROOT}/output/activation-plans"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="${OUTPUT_DIR}/${PLAN_DATE}.md"

# ── budget calculations ───────────────────────────────────────────────────────
RESERVED_CONVERSATION=$(( BUDGET_TOKENS * 32 / 100 ))
AVAILABLE_AGENTS=$(( BUDGET_TOKENS - RESERVED_CONVERSATION ))
AVG_AGENT_COST=8400
ESTIMATED_AGENTS=$(( AVAILABLE_AGENTS / AVG_AGENT_COST ))
(( ESTIMATED_AGENTS < 3 )) && ESTIMATED_AGENTS=3
CHECKPOINT_INTERVAL=$(( ESTIMATED_AGENTS / 3 ))
(( CHECKPOINT_INTERVAL < 2 )) && CHECKPOINT_INTERVAL=2

# ── read recent router decisions ─────────────────────────────────────────────
ROUTER_FILE="${REPO_ROOT}/output/router-decisions.jsonl"
RECENT_MODES=""
if [[ -f "$ROUTER_FILE" ]]; then
  RECENT_MODES="$(tail -20 "$ROUTER_FILE" 2>/dev/null \
    | grep -o '"detected_mode":"[^"]*"' | sort | uniq -c | sort -rn \
    | head -5 | sed 's/.*"\(.*\)"/\1/' | tr '\n' ' ' || true)"
fi

# ── parse ROADMAP.md for pending items ───────────────────────────────────────
ROADMAP="${REPO_ROOT}/ROADMAP.md"
declare -a p0_items=() p1_items=() p2_items=() p3_items=()

if [[ -f "$ROADMAP" ]]; then
  while IFS= read -r line; do
    if printf '%s' "$line" | grep -qiE 'TODO|PROPOSED|pending|\[ \]'; then
      clean_line="$(printf '%s' "$line" | sed 's/^[[:space:]]*[-*]//;s/^[[:space:]]*//' | head -c 80)"
      [[ -z "$clean_line" ]] && continue
      if printf '%s' "$line" | grep -qiE 'P0|critical|blocker|urgent'; then
        p0_items+=("$clean_line")
      elif printf '%s' "$line" | grep -qiE 'P1|high|important'; then
        p1_items+=("$clean_line")
      elif printf '%s' "$line" | grep -qiE 'P2|medium'; then
        p2_items+=("$clean_line")
      else
        p3_items+=("$clean_line")
      fi
    fi
  done < "$ROADMAP"
fi

# ── read agent actuals ────────────────────────────────────────────────────────
ACTUALS_FILE="${REPO_ROOT}/data/agent-actuals.jsonl"
ACTUALS_SUMMARY="No timing data available."
if [[ -f "$ACTUALS_FILE" ]]; then
  actuals_count="$(wc -l < "$ACTUALS_FILE" || echo 0)"
  ACTUALS_SUMMARY="${actuals_count} agent execution records available."
fi

# ── recommended agent sequence ────────────────────────────────────────────────
declare -a sequence=(
  "sdd-spec-writer (P0 if specs pending)"
  "architect (P0 if design decisions needed)"
  "dotnet-developer / typescript-developer (P1 feature work)"
  "test-runner (P1 quality gate after implementation)"
  "code-reviewer (P1 pre-merge review)"
  "drift-auditor (P2 convergence check)"
  "tech-writer (P2 docs update)"
  "security-guardian (P3 periodic scan)"
)

# ── write plan ────────────────────────────────────────────────────────────────
_write_plan() {
  printf '# Activation Plan -- %s\n\n' "$PLAN_DATE"

  printf '## Token Budget\n\n'
  printf 'Context window: %d tokens\n' "$BUDGET_TOKENS"
  printf 'Reserved for conversation: %d (%d%%)\n' \
    "$RESERVED_CONVERSATION" "$(( RESERVED_CONVERSATION * 100 / BUDGET_TOKENS ))"
  printf 'Available for agents: %d\n' "$AVAILABLE_AGENTS"
  printf 'Estimated agents: %d-%d (depending on complexity)\n\n' \
    "$(( ESTIMATED_AGENTS - 2 ))" "$(( ESTIMATED_AGENTS + 3 ))"

  printf '## Priority Queue\n\n'
  idx=1

  if [[ ${#p0_items[@]} -gt 0 ]]; then
    for item in "${p0_items[@]:0:3}"; do
      printf '%d. [P0] %s\n' "$idx" "$item"
      (( idx++ ))
    done
  fi
  if [[ ${#p1_items[@]} -gt 0 ]]; then
    for item in "${p1_items[@]:0:4}"; do
      printf '%d. [P1] %s\n' "$idx" "$item"
      (( idx++ ))
    done
  fi
  if [[ ${#p2_items[@]} -gt 0 ]]; then
    for item in "${p2_items[@]:0:3}"; do
      printf '%d. [P2] %s\n' "$idx" "$item"
      (( idx++ ))
    done
  fi
  if [[ ${#p3_items[@]} -gt 0 ]]; then
    for item in "${p3_items[@]:0:2}"; do
      printf '%d. [P3] %s\n' "$idx" "$item"
      (( idx++ ))
    done
  fi

  if (( idx == 1 )); then
    printf '1. [P1] Review sprint backlog\n'
    printf '2. [P1] Check pending specs\n'
    printf '3. [P2] Run drift audit\n\n'
  else
    printf '\n'
  fi

  printf '## Recommended Agent Sequence\n\n'
  seq_idx=1
  for agent_line in "${sequence[@]}"; do
    printf '%d. %s\n' "$seq_idx" "$agent_line"
    (( seq_idx++ ))
    if (( seq_idx % (CHECKPOINT_INTERVAL + 1) == 0 )); then
      printf '   CHECKPOINT: compact + review context\n'
    fi
  done
  printf '\n'

  printf '## Checkpoints\n\n'
  printf 'Every %d agents: compact context + review progress.\n' "$CHECKPOINT_INTERVAL"
  printf 'If context > 70%%: pause P3 agents.\n'
  printf 'If context > 85%%: emergency compact before continuing.\n\n'

  printf '## Deferred (low priority / not needed today)\n\n'
  printf '%s\n' "- meeting-digest: schedule when meeting transcripts arrive"
  printf '%s\n' "- visual-qa-agent: activate after UI changes"
  printf '%s\n' "- pentester: scheduled scan (check quarterly calendar)"
  printf '\n'

  printf '## Context Signals\n\n'
  if [[ -n "${RECENT_MODES:-}" ]]; then
    printf '%s\n' "- Recent router modes: ${RECENT_MODES}"
  fi
  printf '%s\n' "- Agent timing data: ${ACTUALS_SUMMARY}"
  printf 'Plan generated: %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  printf -- '---\n'
  printf '%s\n' '_Generated by scripts/enterprise/daily-activation-plan.sh (SE-034)_'
  printf '%s\n' '_Review with activation-plan-review.sh before executing._'
}

_write_plan > "$OUTPUT_FILE"
echo "activation plan written: $OUTPUT_FILE"
