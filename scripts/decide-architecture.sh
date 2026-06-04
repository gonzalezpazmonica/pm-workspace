#!/usr/bin/env bash
# decide-architecture.sh — SPEC-158
# Classifies a task description as WORKFLOW (deterministic) or AGENT (loop).
# Bias toward WORKFLOW per Anthropic effective-agents guidance: "workflow first,
# agent only when necessary". Workflow gets +2 starting bonus.
#
# Usage:
#   bash scripts/decide-architecture.sh "task description here"
#   echo "task description" | bash scripts/decide-architecture.sh
#   bash scripts/decide-architecture.sh --json "task ..."
#
# Output (text mode, default):
#   DECISION: WORKFLOW|AGENT
#   workflow_score: N
#   agent_score: N
#   reasons: ...
#   template: <suggested template path>
#
# Output (--json):
#   {"decision":"WORKFLOW|AGENT","workflow_score":N,"agent_score":N,
#    "reasons":["..."],"template":"..."}
#
# Ref: docs/propuestas/SPEC-158-workflow-vs-agent-decision-gate.md

set -uo pipefail

JSON=false
INPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=true; shift ;;
    -h|--help)
      sed -n '2,21p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) INPUT="$INPUT $1"; shift ;;
  esac
done

if [[ -z "${INPUT// }" ]]; then
  if [[ ! -t 0 ]]; then
    INPUT="$(cat)"
  fi
fi

if [[ -z "${INPUT// }" ]]; then
  echo "Error: no task description (pass as arg or stdin)" >&2
  exit 2
fi

# Lowercase for matching
TEXT="$(echo "$INPUT" | tr '[:upper:]' '[:lower:]')"

# Anthropic bias: workflow starts at +1 (workflow first principle).
WORKFLOW_SCORE=1
AGENT_SCORE=0
declare -a REASONS

# ── Workflow signals (deterministic, predictable, sequential) ─────────────
WORKFLOW_WEAK="generate compute extract format convert validate parse transform calculate list count sort render build deploy run query fetch update insert delete read write append rename copy move"
WORKFLOW_STRONG="step 1|step 2|step-by-step|sequentially|deterministic|fixed pipeline|pipeline of|spec-driven|sdd|known steps|defined steps|each file|each item|each entry|for every"

for kw in $WORKFLOW_WEAK; do
  if [[ " $TEXT " == *" $kw "* ]]; then
    WORKFLOW_SCORE=$((WORKFLOW_SCORE+1))
    REASONS+=("workflow:weak match '$kw' (+1)")
  fi
done

while IFS= read -r pat; do
  [[ -z "$pat" ]] && continue
  if echo "$TEXT" | grep -qE "$pat"; then
    WORKFLOW_SCORE=$((WORKFLOW_SCORE+5))
    REASONS+=("workflow:strong match '$pat' (+5)")
  fi
done < <(echo "$WORKFLOW_STRONG" | tr '|' '\n')

# ── Agent signals (loops, exploration, dynamic decisions) ─────────────────
# Three tiers: weak (+1), medium (+2), strong (+5)
AGENT_WEAK="understand analyze review evaluate benchmark"
AGENT_MEDIUM="explore investigate research debug troubleshoot triage decide choose recommend compare"
AGENT_STRONG="loop until|iterate until|trial and error|figure out|find the best|discover which|dynamically adapt|keep trying|until it works|self-correct|self-repair|exploratory|open-ended"

for kw in $AGENT_WEAK; do
  if [[ " $TEXT " == *" $kw "* ]]; then
    AGENT_SCORE=$((AGENT_SCORE+1))
    REASONS+=("agent:weak match '$kw' (+1)")
  fi
done

for kw in $AGENT_MEDIUM; do
  if [[ " $TEXT " == *" $kw "* ]]; then
    AGENT_SCORE=$((AGENT_SCORE+2))
    REASONS+=("agent:medium match '$kw' (+2)")
  fi
done

while IFS= read -r pat; do
  [[ -z "$pat" ]] && continue
  if echo "$TEXT" | grep -qE "$pat"; then
    AGENT_SCORE=$((AGENT_SCORE+5))
    REASONS+=("agent:strong match '$pat' (+5)")
  fi
done < <(echo "$AGENT_STRONG" | tr '|' '\n')

# Tie-break: workflow wins (Anthropic bias enforced)
if [[ $WORKFLOW_SCORE -ge $AGENT_SCORE ]]; then
  DECISION="WORKFLOW"
  TEMPLATE="docs/propuestas/_template-spec.md"
else
  DECISION="AGENT"
  TEMPLATE=".claude/agents/_template.md"
fi

if [[ "$JSON" == true ]]; then
  # Build JSON manually (avoid jq dependency)
  printf '{"decision":"%s","workflow_score":%d,"agent_score":%d,"template":"%s","reasons":[' \
    "$DECISION" "$WORKFLOW_SCORE" "$AGENT_SCORE" "$TEMPLATE"
  first=true
  for r in "${REASONS[@]:-}"; do
    [[ -z "$r" ]] && continue
    if $first; then first=false; else printf ','; fi
    printf '"%s"' "$(echo "$r" | sed 's/"/\\"/g')"
  done
  printf ']}\n'
else
  echo "DECISION: $DECISION"
  echo "workflow_score: $WORKFLOW_SCORE"
  echo "agent_score: $AGENT_SCORE"
  echo "template: $TEMPLATE"
  echo "reasons:"
  for r in "${REASONS[@]:-}"; do
    [[ -z "$r" ]] && continue
    echo "  - $r"
  done
fi

exit 0
