#!/usr/bin/env bash
# agent-discipline-audit.sh — SE-270 Slice 4: Audit agent model tier → maxSteps recommendations.
#
# Reads all 81 agents from .opencode/agents/*.md, determines model tier
# (fast/mid/heavy from frontmatter), generates maxSteps recommendations:
#   fast → 8, mid → 15, heavy → declared (parse existing maxTurns value).
# Generates a JSON report with per-agent recommendations.
# Exits with warning (0 with message) if any agent lacks a recommendation.
#
# Ref: SE-270, Rule #22 (agent size SLA)
# Safety: set -uo pipefail. Read-only. No destructive ops.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
AGENTS_DIR="${AGENTS_DIR:-$REPO_ROOT/.opencode/agents}"
OUTPUT_DIR="$REPO_ROOT/output"
DATE_STR="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUTPUT_DIR/agent-discipline-audit-$DATE_STR.json"

usage() {
  cat <<EOF
Usage: $0 [--quiet] [--json-out PATH]

Audits .opencode/agents/*.md model tier → maxSteps recommendations.
fast→8, mid→15, heavy→declared (reads existing maxTurns or infers).

  --quiet        Suppress stdout summary, write report only.
  --json-out     Override output path (default: $REPORT).

Exit codes:
  0 — all agents have recommendations
  1 — one or more agents lack a recommendation (still generates report)

Output: JSON report at $REPORT
EOF
}

QUIET=0
JSON_OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --json-out) JSON_OUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
[[ -n "$JSON_OUT" ]] && REPORT="$JSON_OUT"

# Tier → recommended maxSteps mapping
declare -A TIER_STEPS
TIER_STEPS[fast]=8
TIER_STEPS[mid]=15
# heavy: declared — parsed from existing maxTurns or inferred

# Parse frontmatter field value (simple key: value, one-line)
parse_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    /^---$/{ if(++c==2) exit; next }
    c==1 && $1 ~ "^"f":" { sub(/^[^:]+:[[:space:]]*/,""); print; exit }
  ' "$file" 2>/dev/null
}

total=0
recommended=0
missing=0
RESULTS=()
WARNINGS=()

while IFS= read -r -d '' agent_file; do
  name=$(basename "$agent_file" .md)
  total=$((total+1))

  model=$(parse_field "$agent_file" "model")
  model="${model:-unknown}"

  existing_max_turns=$(parse_field "$agent_file" "maxTurns")
  existing_max_turns="${existing_max_turns:-}"

  recommended_steps=""
  source=""

  case "$model" in
    fast)
      recommended_steps="${TIER_STEPS[fast]}"
      source="tier-default"
      ;;
    mid)
      recommended_steps="${TIER_STEPS[mid]}"
      source="tier-default"
      ;;
    heavy)
      if [[ -n "$existing_max_turns" ]]; then
        recommended_steps="$existing_max_turns"
        source="declared-maxTurns"
      else
        # Infer from description/permission_level for heavy agents
        permission=$(parse_field "$agent_file" "permission_level")
        case "${permission:-L1}" in
          L3|L4) recommended_steps="30"; source="inferred-from-permission-level" ;;
          L2) recommended_steps="25"; source="inferred-from-permission-level" ;;
          *) recommended_steps="20"; source="inferred-from-permission-level" ;;
        esac
      fi
      ;;
    *)
      recommended_steps=""
      source="unknown-model"
      ;;
  esac

  if [[ -z "$recommended_steps" ]]; then
    missing=$((missing+1))
    WARNINGS+=("{\"agent\":\"$name\",\"model\":\"$model\",\"issue\":\"no-recommendation\"}")
  else
    recommended=$((recommended+1))
  fi

  RESULTS+=("{\"agent\":\"$name\",\"model\":\"$model\",\"current_maxTurns\":\"${existing_max_turns:-none}\",\"recommended_maxSteps\":${recommended_steps:-\"null\"},\"source\":\"$source\"}")
done < <(find "$AGENTS_DIR" -maxdepth 1 -type f -name '*.md' -print0 | sort -z)

# Build JSON
json_entries=$(IFS=,; echo "${RESULTS[*]}")
json_warnings=$(IFS=,; echo "${WARNINGS[*]}")

cat > "$REPORT" <<JSONEOF
{
  "audit": "agent-discipline-audit",
  "ref": "SE-270",
  "date": "$DATE_STR",
  "total_agents": $total,
  "recommended": $recommended,
  "missing": $missing,
  "tier_mapping": {
    "fast": ${TIER_STEPS[fast]},
    "mid": ${TIER_STEPS[mid]},
    "heavy": "declared-from-maxTurns-or-inferred"
  },
  "agents": [$json_entries],
  "warnings": [$json_warnings]
}
JSONEOF

if [[ "$QUIET" -eq 0 ]]; then
  echo "agent-discipline-audit: total=$total recommended=$recommended missing=$missing"
  echo "  report: ${REPORT#$REPO_ROOT/}"
  if [[ "$missing" -gt 0 ]]; then
    echo "  WARNING: $missing agent(s) lack maxSteps recommendation"
  fi
fi

if [[ "$missing" -gt 0 ]]; then
  exit 1
fi
exit 0
