#!/usr/bin/env bash
# client-health-score.sh — SE-024 Client Health Intelligence
set -uo pipefail
# Calculates client health score (0-100) across 6 dimensions.
#
# Usage:
#   scripts/enterprise/client-health-score.sh --client SLUG --tenant SLUG [--json]
#
# 6 dimensions (weights):
#   delivery_adherence    (25%): milestones on-time from billing.jsonl
#   communication_quality (20%): decisions documented, response time signals
#   budget_health         (20%): % billed vs committed
#   nps_trend             (15%): from evaluation.md if present
#   risk_level_dim        (10%): open issues vs capacity
#   strategic_alignment   (10%): % SOW objectives met
#
# Output (--json): {"client","score","dimensions":{...},"risk":"low|medium|high|critical","recommendation":"..."}

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

CLIENT=""
TENANT=""
JSON_OUT=false

# ── arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --client)  CLIENT="$2";  shift 2 ;;
    --tenant)  TENANT="$2";  shift 2 ;;
    --json)    JSON_OUT=true; shift ;;
    --help|-h)
      echo "Usage: client-health-score.sh --client SLUG --tenant SLUG [--json]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CLIENT" || -z "$TENANT" ]]; then
  echo '{"error":"--client and --tenant are required"}' >&2
  exit 2
fi

# ── helper: clamp 0-100 ───────────────────────────────────────────────────────
_clamp() {
  local v="${1:-50}"
  v="${v%.*}"   # strip decimals if any
  (( v < 0 )) && v=0
  (( v > 100 )) && v=100
  echo "$v"
}

# ── locate tenant project data ────────────────────────────────────────────────
TENANT_DIR="${REPO_ROOT}/tenants/${TENANT}"
CLIENT_DIR="${TENANT_DIR}/clients/${CLIENT}"
PROJECT_PATTERN="${TENANT_DIR}/projects"

# ── dimension 1: delivery_adherence (weight 25) ───────────────────────────────
_score_delivery() {
  local billing_file="${CLIENT_DIR}/billing.jsonl"
  local score=70  # neutral baseline
  local signals="no billing data"

  if [[ -f "$billing_file" ]]; then
    local total on_time
    total="$(wc -l < "$billing_file" || echo 0)"
    on_time="$(grep -c '"status"[[:space:]]*:[[:space:]]*"paid"' "$billing_file" 2>/dev/null || echo 0)"
    if (( total > 0 )); then
      score=$(( on_time * 100 / total ))
      signals="${on_time}/${total} milestones on-time"
    fi
  fi
  echo "$score|$signals"
}

# ── dimension 2: communication_quality (weight 20) ───────────────────────────
_score_communication() {
  local score=65
  local signals="no communication data"

  # Count decision docs as proxy for documented communication
  local dec_count
  dec_count="$(find "${REPO_ROOT}/output" -name "decision*.md" -newer /dev/null 2>/dev/null | wc -l || echo 0)"
  if (( dec_count > 5 )); then
    score=80
    signals="${dec_count} decisions documented"
  elif (( dec_count > 0 )); then
    score=65
    signals="${dec_count} decisions documented"
  fi
  echo "$score|$signals"
}

# ── dimension 3: budget_health (weight 20) ───────────────────────────────────
_score_budget() {
  local billing_file="${CLIENT_DIR}/billing.jsonl"
  local score=70
  local signals="no budget data"

  if [[ -f "$billing_file" ]]; then
    local billed committed
    billed="$(grep -c '"billed"' "$billing_file" 2>/dev/null || echo 0)"
    committed="$(wc -l < "$billing_file" || echo 1)"
    if (( committed > 0 )); then
      score=$(( billed * 100 / committed ))
      signals="${billed}/${committed} budget items billed"
    fi
  fi
  echo "$score|$signals"
}

# ── dimension 4: nps_trend (weight 15) ───────────────────────────────────────
_score_nps() {
  local eval_file="${CLIENT_DIR}/evaluation.md"
  local score=70
  local signals="no NPS data"

  if [[ -f "$eval_file" ]]; then
    local nps_val
    nps_val="$(grep -i 'nps' "$eval_file" 2>/dev/null | grep -o '[0-9]\+' | head -1 || true)"
    if [[ -n "$nps_val" ]]; then
      # NPS 0-10 → scale to 0-100
      score=$(( nps_val * 10 ))
      score="$(_clamp "$score")"
      signals="NPS ${nps_val} from evaluation.md"
    fi
  fi
  echo "$score|$signals"
}

# ── dimension 5: risk_level_dim (weight 10) ───────────────────────────────────
_score_risk() {
  local score=75
  local signals="no issue data"

  # Proxy: count open issues from any issues tracker file
  local issues_file="${CLIENT_DIR}/issues.jsonl"
  if [[ -f "$issues_file" ]]; then
    local open_count
    open_count="$(grep -c '"status"[[:space:]]*:[[:space:]]*"open"' "$issues_file" 2>/dev/null || echo 0)"
    if (( open_count == 0 )); then
      score=90; signals="0 open issues"
    elif (( open_count <= 3 )); then
      score=75; signals="${open_count} open issues"
    elif (( open_count <= 7 )); then
      score=50; signals="${open_count} open issues"
    else
      score=25; signals="${open_count} open issues (high)"
    fi
  fi
  echo "$score|$signals"
}

# ── dimension 6: strategic_alignment (weight 10) ─────────────────────────────
_score_alignment() {
  local sow_file="${CLIENT_DIR}/sow.md"
  local score=70
  local signals="no SOW data"

  if [[ -f "$sow_file" ]]; then
    local total done
    total="$(grep -cE '^\s*[-*]' "$sow_file" 2>/dev/null || echo 0)"
    done="$(grep -ciE '\[x\]|\bcompleted\b|\bdone\b' "$sow_file" 2>/dev/null || echo 0)"
    if (( total > 0 )); then
      score=$(( done * 100 / total ))
      signals="${done}/${total} SOW objectives met"
    fi
  fi
  echo "$score|$signals"
}

# ── calculate weighted score ─────────────────────────────────────────────────
IFS='|' read -r d1_score d1_signals <<< "$(_score_delivery)"
IFS='|' read -r d2_score d2_signals <<< "$(_score_communication)"
IFS='|' read -r d3_score d3_signals <<< "$(_score_budget)"
IFS='|' read -r d4_score d4_signals <<< "$(_score_nps)"
IFS='|' read -r d5_score d5_signals <<< "$(_score_risk)"
IFS='|' read -r d6_score d6_signals <<< "$(_score_alignment)"

# Weighted sum: 25+20+20+15+10+10 = 100
total_score=$(( d1_score*25 + d2_score*20 + d3_score*20 + d4_score*15 + d5_score*10 + d6_score*10 ))
final_score=$(( total_score / 100 ))
final_score="$(_clamp "$final_score")"

# ── risk classification ───────────────────────────────────────────────────────
if (( final_score >= 80 )); then
  risk="low"
  recommendation="Account in good standing. Monitor for trend changes."
elif (( final_score >= 60 )); then
  risk="medium"
  recommendation="Schedule account review. Address weakest dimensions proactively."
elif (( final_score >= 40 )); then
  risk="high"
  recommendation="Immediate account review required. Multiple dimensions degraded."
else
  risk="critical"
  recommendation="URGENT: Escalate to account partner. Churn risk is significant."
fi

# ── output ────────────────────────────────────────────────────────────────────
if [[ "$JSON_OUT" == "true" ]]; then
  printf '{\n'
  printf '  "client": "%s",\n' "$CLIENT"
  printf '  "tenant": "%s",\n' "$TENANT"
  printf '  "as_of": "%s",\n' "$(date -u +%Y-%m-%d)"
  printf '  "score": %d,\n' "$final_score"
  printf '  "dimensions": {\n'
  printf '    "delivery_adherence":    {"score": %d, "weight": 0.25, "signals": "%s"},\n' "$d1_score" "$d1_signals"
  printf '    "communication_quality": {"score": %d, "weight": 0.20, "signals": "%s"},\n' "$d2_score" "$d2_signals"
  printf '    "budget_health":         {"score": %d, "weight": 0.20, "signals": "%s"},\n' "$d3_score" "$d3_signals"
  printf '    "nps_trend":             {"score": %d, "weight": 0.15, "signals": "%s"},\n' "$d4_score" "$d4_signals"
  printf '    "risk_level_dim":        {"score": %d, "weight": 0.10, "signals": "%s"},\n' "$d5_score" "$d5_signals"
  printf '    "strategic_alignment":   {"score": %d, "weight": 0.10, "signals": "%s"}\n'  "$d6_score" "$d6_signals"
  printf '  },\n'
  printf '  "risk": "%s",\n' "$risk"
  printf '  "recommendation": "%s"\n' "$recommendation"
  printf '}\n'
else
  printf 'Client:      %s\n' "$CLIENT"
  printf 'Tenant:      %s\n' "$TENANT"
  printf 'Score:       %d/100\n' "$final_score"
  printf 'Risk:        %s\n' "$risk"
  printf 'Dimensions:\n'
  printf '  delivery_adherence    (25%%): %d — %s\n' "$d1_score" "$d1_signals"
  printf '  communication_quality (20%%): %d — %s\n' "$d2_score" "$d2_signals"
  printf '  budget_health         (20%%): %d — %s\n' "$d3_score" "$d3_signals"
  printf '  nps_trend             (15%%): %d — %s\n' "$d4_score" "$d4_signals"
  printf '  risk_level_dim        (10%%): %d — %s\n' "$d5_score" "$d5_signals"
  printf '  strategic_alignment   (10%%): %d — %s\n' "$d6_score" "$d6_signals"
  printf 'Recommendation: %s\n' "$recommendation"
fi
