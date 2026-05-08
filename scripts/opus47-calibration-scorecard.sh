#!/usr/bin/env bash
# opus47-calibration-scorecard.sh — SE-070 Slice 1
#
# Lists all agents on claude-sonnet-4-6 with estimated cost delta if upgraded
# to claude-opus-4-7 at effort: xhigh. Emits YAML + markdown scorecard.
#
# This script scaffolds the DECISION infrastructure. It does NOT run evals
# and does NOT auto-upgrade any agent. Execution is per SE-070 Slice 4
# (deferred).
#
# Ref: SE-070 — Opus 4.7 calibration scorecard

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
AGENTS_DIR="$REPO_ROOT/.claude/agents"
GOLDEN_DIR="$REPO_ROOT/tests/golden/opus47-calibration"
OUTPUT_DIR="$REPO_ROOT/output"
DATE_STR="$(date +%Y%m%d)"
YAML_OUT="$OUTPUT_DIR/opus47-calibration-$DATE_STR.yaml"
MD_OUT="$OUTPUT_DIR/opus47-calibration-$DATE_STR.md"

# Cost model (approximate per Anthropic published rates 2026-04).
# Units: USD per MTok (million tokens) — used for relative deltas only.
SONNET_IN_COST_PER_MTOK=3.00
SONNET_OUT_COST_PER_MTOK=15.00
OPUS_IN_COST_PER_MTOK=15.00
OPUS_OUT_COST_PER_MTOK=75.00
# xhigh effort adds ~2.5x token consumption on thinking vs default.
XHIGH_THINKING_MULT=2.5

usage() {
  cat <<EOF
Usage: $0 [--quiet] [--json]

Scans .opencode/agents/*.md. For each agent on claude-sonnet-4-6, computes
an estimated cost delta if upgraded to claude-opus-4-7 at effort: xhigh.
Flags which agents have golden-set tests available for A/B eval.

Outputs:
  $YAML_OUT — machine-readable YAML scorecard
  $MD_OUT   — human-readable markdown summary

  --quiet    Suppress stdout summary.
  --json     Emit JSON array to stdout (skip file outputs).

Exit codes:
  0 — scorecard generated successfully
  1 — no agents found or read error
  2 — usage error

No evals are run. No agents are modified. Decisions are human.

Ref: SE-070 Opus 4.7 calibration scorecard
EOF
}

QUIET=0
JSON_MODE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --json) JSON_MODE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

# Extract agent model (first 30 frontmatter lines).
get_model() {
  head -30 "$1" 2>/dev/null | grep -m1 '^model:' | awk -F: '{print $2}' | tr -d ' "'
}

# Detect if agent has golden-set available.
has_golden() {
  local agent_name="$1"
  [[ -d "$GOLDEN_DIR/$agent_name" ]] && [[ -n "$(ls -A "$GOLDEN_DIR/$agent_name" 2>/dev/null)" ]]
}

# Cost delta: percent increase per 1k I/O tokens on upgrade.
# Simple model: opus_xhigh vs sonnet default.
# delta% = (opus_in + opus_out * xhigh_mult - sonnet_in - sonnet_out) / (sonnet_in + sonnet_out) * 100
cost_delta_pct() {
  python3 <<'PYEOF'
SONNET_IN = 3.00
SONNET_OUT = 15.00
OPUS_IN = 15.00
OPUS_OUT = 75.00
XHIGH_MULT = 2.5
sonnet_total = SONNET_IN + SONNET_OUT
opus_total_xhigh = OPUS_IN + OPUS_OUT * XHIGH_MULT
delta_pct = ((opus_total_xhigh - sonnet_total) / sonnet_total) * 100
print(f"{delta_pct:.0f}")
PYEOF
}

COST_DELTA_PCT=$(cost_delta_pct)

total=0
sonnet_count=0
sonnet_with_golden=0

# Build results
RESULTS=()
for agent_file in "$AGENTS_DIR"/*.md; do
  [[ -f "$agent_file" ]] || continue
  total=$((total+1))
  name=$(basename "$agent_file" .md)
  model=$(get_model "$agent_file")
  model="${model:-unknown}"
  if [[ "$model" == "claude-sonnet-4-6" ]]; then
    sonnet_count=$((sonnet_count+1))
    golden="false"
    recommend="defer"
    if has_golden "$name"; then
      golden="true"
      sonnet_with_golden=$((sonnet_with_golden+1))
      recommend="eval"
    fi
    RESULTS+=("$name|$model|$golden|$recommend")
  fi
done

if [[ $total -eq 0 ]]; then
  echo "ERROR: no agents found in $AGENTS_DIR" >&2
  exit 1
fi

# JSON output short-circuit
if [[ "$JSON_MODE" -eq 1 ]]; then
  python3 <<PYEOF
import json
data = {
  "date": "$DATE_STR",
  "total_agents": $total,
  "sonnet_count": $sonnet_count,
  "sonnet_with_golden": $sonnet_with_golden,
  "cost_delta_pct_xhigh_upgrade": $COST_DELTA_PCT,
  "agents": []
}
rows = '''$(printf '%s\n' "${RESULTS[@]}")'''
for row in rows.strip().split('\n'):
  if not row: continue
  name, model, golden, recommend = row.split('|')
  data["agents"].append({
    "name": name,
    "current_model": model,
    "has_golden_set": golden == "true",
    "recommend": recommend
  })
print(json.dumps(data, indent=2))
PYEOF
  exit 0
fi

# YAML output
{
  echo "# SE-070 Opus 4.7 calibration scorecard — $DATE_STR"
  echo "# Machine-readable. See .md sibling for human summary."
  echo ""
  echo "date: $DATE_STR"
  echo "total_agents: $total"
  echo "sonnet_count: $sonnet_count"
  echo "sonnet_with_golden: $sonnet_with_golden"
  echo "cost_delta_pct_xhigh_upgrade: $COST_DELTA_PCT"
  echo ""
  echo "agents:"
  for row in "${RESULTS[@]}"; do
    IFS='|' read -r name model golden recommend <<< "$row"
    echo "  - name: $name"
    echo "    current_model: $model"
    echo "    has_golden_set: $golden"
    echo "    recommend: $recommend"
  done
} > "$YAML_OUT"

# Markdown output
{
  echo "# Opus 4.7 calibration scorecard — $DATE_STR"
  echo ""
  echo '**SE-070 Slice 1 output.** Candidates for A/B eval of `claude-sonnet-4-6` → `claude-opus-4-7` xhigh.'
  echo ""
  echo "## Summary"
  echo ""
  echo "| Metric | Value |"
  echo "|---|---:|"
  echo "| Total agents | $total |"
  echo "| Sonnet-4-6 (upgrade candidates) | $sonnet_count |"
  echo "| With golden-set | $sonnet_with_golden |"
  echo "| Estimated cost delta per I/O unit | +${COST_DELTA_PCT}% (opus xhigh vs sonnet) |"
  echo ""
  echo "**Interpretation**: upgrading a single agent to opus-4-7 xhigh increases cost per invocation by ~${COST_DELTA_PCT}%. Upgrade only justified if quality delta >2x this (rough heuristic)."
  echo ""
  echo "## Sonnet-4-6 agents (candidates for A/B eval)"
  echo ""
  echo "| Agent | Current model | Golden-set | Recommend |"
  echo "|---|---|:---:|---|"
  for row in "${RESULTS[@]}"; do
    IFS='|' read -r name model golden recommend <<< "$row"
    local_golden="❌"
    [[ "$golden" == "true" ]] && local_golden="✅"
    echo "| \`$name\` | $model | $local_golden | $recommend |"
  done
  echo ""
  echo "## Recommendations"
  echo ""
  if [[ "$sonnet_with_golden" -gt 0 ]]; then
    echo "- **$sonnet_with_golden agents** have golden-set → execute A/B eval per SE-070 Slice 4 playbook."
  else
    echo '- **Zero agents** have golden-set tests. Slice 2 must bootstrap `tests/golden/opus47-calibration/` templates before Slice 4 execution.'
  fi
  echo "- Remaining $((sonnet_count - sonnet_with_golden)) agents: \`recommend: defer\` until golden-set exists."
  echo "- Opus-4-7 agents ($((total - sonnet_count - $(grep -l "^model: claude-haiku" "$AGENTS_DIR"/*.md 2>/dev/null | wc -l)))) and haiku agents are NOT in scope for this scorecard."
  echo ""
  echo "## Next steps"
  echo ""
  echo "1. Slice 2: populate \`$GOLDEN_DIR/<agent-name>/\` with A/B test pairs"
  echo "2. Slice 3: follow \`docs/rules/domain/opus47-calibration-playbook.md\` for each candidate"
  echo "3. Slice 4: eval 3 highest-leverage agents (business-analyst, drift-auditor, tech-writer)"
  echo ""
  echo "---"
  echo ""
  echo "Generated by \`scripts/opus47-calibration-scorecard.sh\`."
} > "$MD_OUT"

if [[ "$QUIET" -eq 0 ]]; then
  echo "opus47-calibration-scorecard: total=$total sonnet=$sonnet_count with_golden=$sonnet_with_golden cost_delta=+${COST_DELTA_PCT}%"
  echo "  yaml: ${YAML_OUT#$REPO_ROOT/}"
  echo "  md:   ${MD_OUT#$REPO_ROOT/}"
fi

exit 0
