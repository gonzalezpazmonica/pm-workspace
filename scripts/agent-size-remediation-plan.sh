#!/usr/bin/env bash
# agent-size-remediation-plan.sh — SE-052 Slice 1 agent-size analyzer.
#
# Audita agentes en `.opencode/agents/*.md` contra Rule #22 (max 4KB).
# Produce plan de remediación con hit-list ordenado por tamaño DESC:
#   - Top-N agentes offenders (tamaño actual vs budget)
#   - Estimated savings por extracción de bloques comunes
#   - Bloques candidatos a extraer (Identity, Success Metrics, Decision Trees)
#
# NO aplica remediación — solo propone. SE-052 Slice 2 ejecuta.
#
# Usage:
#   agent-size-remediation-plan.sh
#   agent-size-remediation-plan.sh --budget 4096 --top 10
#   agent-size-remediation-plan.sh --json
#
# Exit codes:
#   0 — sin violaciones (all within budget)
#   1 — violaciones detectadas (plan emitido)
#   2 — usage error
#
# Ref: SE-052, Rule #22, audit-arquitectura-20260420.md §4.3
# Safety: read-only. set -uo pipefail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/.claude/agents"

BUDGET=4096
TOP=10
JSON=0

# Common blocks that can be extracted to shared references
COMMON_BLOCKS=("Identity" "Success Metrics" "Decision Trees" "Activation triggers" "Common Pitfalls")

usage() {
  cat <<EOF
Usage:
  $0 [options]

Options:
  --budget N    Max size per agent file in bytes (default 4096 = Rule #22)
  --top N       Top N offenders to report (default 10)
  --json        JSON output

Audita agents vs Rule #22. Emite plan de remediación con hit-list +
bloques candidatos a extraer a referencias compartidas.
Ref: SE-052, Rule #22.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --budget) BUDGET="$2"; shift 2 ;;
    --top) TOP="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

for v in BUDGET TOP; do
  val="${!v}"
  if ! [[ "$val" =~ ^[0-9]+$ ]] || [[ "$val" -lt 1 ]]; then
    echo "ERROR: --${v,,} must be positive integer" >&2; exit 2
  fi
done

[[ ! -d "$AGENTS_DIR" ]] && { echo "ERROR: agents dir not found" >&2; exit 2; }

# Collect agents with sizes
AGENT_SIZES=()
TOTAL_AGENTS=0
TOTAL_OVER_BUDGET=0
TOTAL_BYTES_OVER=0

for f in "$AGENTS_DIR"/*.md; do
  [[ -f "$f" ]] || continue
  TOTAL_AGENTS=$((TOTAL_AGENTS + 1))
  size=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
  AGENT_SIZES+=("$size|$f")
  if [[ "$size" -gt "$BUDGET" ]]; then
    TOTAL_OVER_BUDGET=$((TOTAL_OVER_BUDGET + 1))
    TOTAL_BYTES_OVER=$((TOTAL_BYTES_OVER + size - BUDGET))
  fi
done

# Sort DESC by size
IFS=$'\n' sorted=($(printf '%s\n' "${AGENT_SIZES[@]}" | sort -t'|' -k1,1rn))
unset IFS

# For top offenders, detect candidate extractable blocks
detect_blocks() {
  local f="$1"
  local found=""
  for block in "${COMMON_BLOCKS[@]}"; do
    if grep -qiE "^##+ .*${block}" "$f" 2>/dev/null; then
      [[ -n "$found" ]] && found="$found,"
      found="${found}${block}"
    fi
  done
  echo "$found"
}

# Estimate potential savings per file
# Heuristic: if 3+ common blocks detected, assume ~30% reduction possible
estimate_savings() {
  local f="$1" size="$2"
  local blocks
  blocks=$(detect_blocks "$f")
  local block_count
  block_count=$(echo "$blocks" | awk -F',' '{print NF}')
  if [[ "$block_count" -ge 3 ]]; then
    echo $(( size * 3 / 10 ))  # 30% savings
  elif [[ "$block_count" -ge 1 ]]; then
    echo $(( size * 15 / 100 ))  # 15%
  else
    echo 0
  fi
}

EXIT_CODE=0
[[ "$TOTAL_OVER_BUDGET" -gt 0 ]] && EXIT_CODE=1

if [[ "$JSON" -eq 1 ]]; then
  offenders_json=""
  n=0
  for entry in "${sorted[@]}"; do
    [[ $n -ge $TOP ]] && break
    size="${entry%%|*}"
    file="${entry#*|}"
    [[ "$size" -le "$BUDGET" ]] && continue
    rel=${file#$PROJECT_ROOT/}
    blocks=$(detect_blocks "$file")
    savings=$(estimate_savings "$file" "$size")
    offenders_json+="{\"file\":\"$rel\",\"size_bytes\":$size,\"over_budget\":$((size - BUDGET)),\"extractable_blocks\":\"$blocks\",\"estimated_savings_bytes\":$savings},"
    n=$((n + 1))
  done
  offenders_json="[${offenders_json%,}]"
  cat <<JSON
{"total_agents":$TOTAL_AGENTS,"over_budget":$TOTAL_OVER_BUDGET,"total_bytes_over":$TOTAL_BYTES_OVER,"budget":$BUDGET,"top_offenders":$offenders_json}
JSON
else
  echo "=== SE-052 Agent Size Remediation Plan ==="
  echo ""
  echo "Budget:              $BUDGET bytes (Rule #22)"
  echo "Total agents:        $TOTAL_AGENTS"
  echo "Over budget:         $TOTAL_OVER_BUDGET"
  echo "Total bytes over:    $TOTAL_BYTES_OVER"
  echo ""
  if [[ "$TOTAL_OVER_BUDGET" -gt 0 ]]; then
    echo "Top $TOP offenders (DESC by size):"
    printf "  %-40s %10s %10s %s\n" "FILE" "SIZE" "OVER" "EXTRACTABLE_BLOCKS"
    n=0
    for entry in "${sorted[@]}"; do
      [[ $n -ge $TOP ]] && break
      size="${entry%%|*}"
      file="${entry#*|}"
      [[ "$size" -le "$BUDGET" ]] && continue
      rel=${file#$PROJECT_ROOT/}
      blocks=$(detect_blocks "$file")
      over=$((size - BUDGET))
      printf "  %-40s %10d %10d %s\n" "$(basename "$rel")" "$size" "$over" "${blocks:-none}"
      n=$((n + 1))
    done
    echo ""
    echo "Recommended remediation path:"
    echo "  1. Extract 'Identity' blocks → docs/rules/domain/agent-common-identity.md"
    echo "  2. Extract 'Success Metrics' → agent-common-metrics.md"
    echo "  3. Extract 'Decision Trees' → per-role shared references"
    echo "  4. Reference with @include or front-matter 'extends:'"
    echo "  5. Re-run: bash $0 to verify reduction"
  else
    echo "VERDICT: PASS (all agents within budget)"
  fi
fi

exit $EXIT_CODE
