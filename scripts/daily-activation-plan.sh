#!/usr/bin/env bash
set -uo pipefail
# daily-activation-plan.sh — SE-034: Daily Agent Activation Plan
#
# Generates a prioritized plan mapping sprint backlog items to agents
# with token budgets. The PM reviews and adjusts before executing.
#
# Usage:
#   bash scripts/daily-activation-plan.sh generate  # Create today's plan
#   bash scripts/daily-activation-plan.sh show      # Show active plan
#   bash scripts/daily-activation-plan.sh status     # Budget summary

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/output/daily-plans}"
TODAY=$(date +%Y-%m-%d)
PLAN_FILE="$OUTPUT_DIR/${TODAY}.md"

# Token budget constants (from agent-context-budget.md)
CONTEXT_WINDOW=200000
RESERVED_CONVERSATION=65000
AVAILABLE_FOR_AGENTS=$(( CONTEXT_WINDOW - RESERVED_CONVERSATION ))

# Agent budget tiers
BUDGET_HEAVY=12000
BUDGET_STANDARD=8000
BUDGET_LIGHT=4000
BUDGET_MINIMAL=2000

log() { echo "[daily-plan] $*" >&2; }

# ── Agent tier lookup ────────────────────────────────────────────────────────

agent_budget() {
  local agent="$1"
  case "$agent" in
    architect|security-guardian|code-reviewer|court-orchestrator|pentester)
      echo "$BUDGET_HEAVY" ;;
    *-developer|business-analyst|test-engineer|test-runner|sdd-spec-writer|meeting-digest)
      echo "$BUDGET_STANDARD" ;;
    commit-guardian|diagram-architect|tech-writer|drift-auditor|*-judge|fix-assigner)
      echo "$BUDGET_LIGHT" ;;
    azure-devops-operator|infrastructure-agent)
      echo "$BUDGET_MINIMAL" ;;
    *)
      echo "$BUDGET_STANDARD" ;;
  esac
}

agent_tier_name() {
  local budget="$1"
  case "$budget" in
    "$BUDGET_HEAVY")   echo "Heavy" ;;
    "$BUDGET_STANDARD") echo "Standard" ;;
    "$BUDGET_LIGHT")   echo "Light" ;;
    "$BUDGET_MINIMAL") echo "Minimal" ;;
    *)                 echo "Standard" ;;
  esac
}

# ── Scan backlog for actionable items ────────────────────────────────────────

scan_backlog() {
  local items=()
  local priority_counter=0

  # Source 1: Savia Flow backlog (local markdown PBIs)
  for proj_dir in "$REPO_ROOT"/projects/*/; do
    [[ -d "$proj_dir/backlog" ]] || continue
    local proj_name
    proj_name=$(basename "$proj_dir")

    while IFS= read -r -d '' pbi_file; do
      local title priority state assigned agent_type
      title=$(grep -m1 '^# \|^title:' "$pbi_file" 2>/dev/null | sed 's/^# //;s/^title: *//' || basename "$pbi_file" .md)
      priority=$(grep -m1 '^priority:' "$pbi_file" 2>/dev/null | awk '{print $2}' || echo "P2")
      state=$(grep -m1 '^state:\|^status:' "$pbi_file" 2>/dev/null | awk '{print $2}' || echo "backlog")
      assigned=$(grep -m1 '^assigned:\|^developer_type:' "$pbi_file" 2>/dev/null | awk '{print $2}' || echo "")

      # Only include active items
      case "$state" in
        done|closed|completed|verified) continue ;;
      esac

      # Map to agent
      if [[ -n "$assigned" ]]; then
        agent_type="$assigned"
      else
        agent_type="sdd-spec-writer"
      fi

      items+=("${priority:-P2}|${title}|${agent_type}|${proj_name}|$(basename "$pbi_file")")
      (( priority_counter++ )) || true
    done < <(find "$proj_dir/backlog" -name "*.md" -print0 2>/dev/null)
  done

  # Source 2: Pending specs with approved status
  while IFS= read -r -d '' spec_file; do
    local spec_status
    spec_status=$(grep -m1 '^approval_status:\|^status:' "$spec_file" 2>/dev/null | awk '{print $2}' || echo "draft")
    case "$spec_status" in
      approved|ready)
        local dev_type spec_title
        dev_type=$(grep -m1 '^developer_type:' "$spec_file" 2>/dev/null | awk '{print $2}' || echo "dotnet-developer")
        spec_title=$(grep -m1 '^# ' "$spec_file" 2>/dev/null | sed 's/^# //' || basename "$spec_file")
        items+=("P1|${spec_title}|${dev_type}|specs|$(basename "$spec_file")")
        (( priority_counter++ )) || true
        ;;
    esac
  done < <(find "$REPO_ROOT"/projects/*/specs -name "*.spec.md" -print0 2>/dev/null)

  # Sort by priority (P0 first)
  printf '%s\n' "${items[@]}" 2>/dev/null | sort -t'|' -k1,1
}

# ── Generate plan ────────────────────────────────────────────────────────────

cmd_generate() {
  mkdir -p "$OUTPUT_DIR"

  local items_sorted
  items_sorted=$(scan_backlog)
  local total_budget_used=0
  local queue_num=0
  local plan_lines=()
  local deferred_lines=()

  while IFS='|' read -r priority title agent project source; do
    [[ -z "$priority" ]] && continue
    local budget
    budget=$(agent_budget "$agent")
    local tier
    tier=$(agent_tier_name "$budget")

    local new_total=$(( total_budget_used + budget ))

    if (( new_total > AVAILABLE_FOR_AGENTS )); then
      deferred_lines+=("- ${title} (${agent}, ${tier} ${budget} tokens) — budget exceeded")
      continue
    fi

    (( queue_num++ )) || true
    total_budget_used=$new_total
    plan_lines+=("${queue_num}. [${priority}] ${agent} → ${title} (${tier}, ${budget}t, project: ${project})")
  done <<< "$items_sorted"

  # Write plan
  {
    echo "# Activation Plan — ${TODAY}"
    echo ""
    echo "## Budget"
    echo "- Context window: $(( CONTEXT_WINDOW / 1000 ))K tokens"
    echo "- Reserved for conversation: $(( RESERVED_CONVERSATION / 1000 ))K"
    echo "- Available for agents: $(( AVAILABLE_FOR_AGENTS / 1000 ))K"
    echo "- Allocated: $(( total_budget_used / 1000 ))K (${queue_num} agents)"
    echo "- Remaining: $(( (AVAILABLE_FOR_AGENTS - total_budget_used) / 1000 ))K"
    echo ""
    echo "## Priority Queue"
    if (( ${#plan_lines[@]} > 0 )); then
      printf '%s\n' "${plan_lines[@]}"
    else
      echo "No actionable items in backlog."
    fi
    echo ""
    echo "## Deferred"
    if (( ${#deferred_lines[@]} > 0 )); then
      printf '%s\n' "${deferred_lines[@]}"
    else
      echo "None — all items fit within budget."
    fi
  } > "$PLAN_FILE"

  echo "$PLAN_FILE"
}

# ── Show plan ────────────────────────────────────────────────────────────────

cmd_show() {
  if [[ -f "$PLAN_FILE" ]]; then
    cat "$PLAN_FILE"
  else
    echo "No plan for today (${TODAY}). Run: bash scripts/daily-activation-plan.sh generate"
    return 1
  fi
}

# ── Status ───────────────────────────────────────────────────────────────────

cmd_status() {
  local plan_count=0
  [[ -d "$OUTPUT_DIR" ]] && plan_count=$(find "$OUTPUT_DIR" -name "*.md" 2>/dev/null | wc -l)

  local today_exists="no"
  [[ -f "$PLAN_FILE" ]] && today_exists="yes"

  local items_in_plan=0
  if [[ -f "$PLAN_FILE" ]]; then
    items_in_plan=$(grep -cE '^\d+\. \[P' "$PLAN_FILE" 2>/dev/null || echo 0)
  fi

  cat <<EOS
Agent Activation Plan Status (SE-034)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Today's plan:     ${today_exists}
Items in queue:   ${items_in_plan}
Total plans:      ${plan_count}
Budget available: $(( AVAILABLE_FOR_AGENTS / 1000 ))K tokens
Plan file:        ${PLAN_FILE}
EOS
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "${1:-status}" in
  generate) cmd_generate ;;
  show)     cmd_show     ;;
  status)   cmd_status   ;;
  *)        echo "Usage: daily-activation-plan.sh {generate|show|status}" >&2; exit 1 ;;
esac
