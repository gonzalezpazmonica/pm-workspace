#!/usr/bin/env bash
set -uo pipefail
# project-valuation.sh — SE-016 Project Valuation (Business-Case-as-Code)
#
# Calcula el valor de negocio de un proyecto (NPV, IRR, payback, risk-adjusted).
#
# Usage:
#   bash scripts/enterprise/project-valuation.sh \
#     --project SLUG --tenant SLUG [--config FILE]
#
# Config FILE (YAML/env):
#   revenue_impact=NUM        # anual EUR
#   cost_reduction=NUM        # anual EUR
#   risk_mitigation=NUM       # valor riesgo evitado EUR
#   strategic_value=NUM       # escala 0-10
#   investment=NUM            # inversión total EUR
#   wacc=NUM                  # WACC como decimal (ej: 0.08 = 8%)
#   years=NUM                 # horizonte temporal (default: 3)
#   risk_factor=NUM           # factor de riesgo 0-1 (default: 0.2)
#
# Output JSON: {npv_eur, irr_pct, payback_months, risk_adjusted_value, confidence}
#
# Exit codes: 0 ok | 1 error | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-016-project-valuation.md

PROJECT=""
TENANT=""
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --tenant)  TENANT="$2";  shift 2 ;;
    --config)  CONFIG_FILE="$2"; shift 2 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PROJECT" || -z "$TENANT" ]]; then
  echo "ERROR: --project and --tenant are required" >&2
  exit 2
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

# Default values
revenue_impact=0
cost_reduction=0
risk_mitigation=0
strategic_value=5
investment=100000
wacc=0.08
years=3
risk_factor=0.20

# Load from config file if provided
if [[ -n "$CONFIG_FILE" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config file not found: ${CONFIG_FILE}" >&2
    exit 1
  fi
  # Source as env vars (key=value format)
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
    key="${key// /}"
    val="${val// /}"
    case "$key" in
      revenue_impact)   revenue_impact="$val"   ;;
      cost_reduction)   cost_reduction="$val"   ;;
      risk_mitigation)  risk_mitigation="$val"  ;;
      strategic_value)  strategic_value="$val"  ;;
      investment)       investment="$val"        ;;
      wacc)             wacc="$val"             ;;
      years)            years="$val"            ;;
      risk_factor)      risk_factor="$val"      ;;
    esac
  done < "$CONFIG_FILE"
fi

# Validate numeric inputs
for var in revenue_impact cost_reduction risk_mitigation investment wacc years risk_factor; do
  val="${!var}"
  if ! [[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "ERROR: ${var} must be numeric, got '${val}'" >&2
    exit 2
  fi
done

# Calculate NPV = sum(annual_cashflow_t / (1+wacc)^t) - investment
# annual_cashflow = revenue_impact + cost_reduction (annual benefits)
npv=$(awk -v rev="$revenue_impact" -v cost="$cost_reduction" \
         -v inv="$investment" -v r="$wacc" -v n="$years" '
BEGIN {
  annual = rev + cost
  npv = -inv
  for (t = 1; t <= n; t++) {
    npv += annual / (1 + r)^t
  }
  printf "%.0f", npv
}')

# IRR approximation (binary search): find r where NPV=0
# Using annual cashflow same as NPV calculation
irr=$(awk -v rev="$revenue_impact" -v cost="$cost_reduction" \
          -v inv="$investment" -v n="$years" '
BEGIN {
  annual = rev + cost
  if (annual <= 0 || inv <= 0) { print "0"; exit }
  lo = -0.99; hi = 10.0
  for (i = 0; i < 100; i++) {
    mid = (lo + hi) / 2
    npv_mid = -inv
    for (t = 1; t <= n; t++) {
      npv_mid += annual / (1 + mid)^t
    }
    if (npv_mid > 0) lo = mid
    else hi = mid
    if (hi - lo < 0.0001) break
  }
  printf "%.1f", mid * 100
}')

# Payback months = investment / (annual_cashflow / 12)
payback=$(awk -v rev="$revenue_impact" -v cost="$cost_reduction" -v inv="$investment" '
BEGIN {
  annual = rev + cost
  if (annual <= 0) { print "999"; exit }
  printf "%.0f", (inv / annual) * 12
}')

# Risk-adjusted value = NPV * (1 - risk_factor)
risk_adjusted=$(awk -v npv="$npv" -v rf="$risk_factor" '
BEGIN { printf "%.0f", npv * (1 - rf) }')

# Confidence level based on strategic_value (0-10 → low/medium/high)
if (( $(echo "$strategic_value >= 7" | awk '{print ($1 >= 7)}') )); then
  confidence="high"
elif (( $(echo "$strategic_value >= 4" | awk '{print ($1 >= 4)}') )); then
  confidence="medium"
else
  confidence="low"
fi

# Write valuation to project dir
VALUATION_DIR="${REPO_ROOT}/tenants/${TENANT}/projects/${PROJECT}/valuation"
mkdir -p "$VALUATION_DIR"
COMPUTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "${VALUATION_DIR}/business-case.yaml" <<EOF
project: "${PROJECT}"
tenant: "${TENANT}"
computed_at: "${COMPUTED_AT}"
inputs:
  revenue_impact_eur: ${revenue_impact}
  cost_reduction_eur: ${cost_reduction}
  risk_mitigation_eur: ${risk_mitigation}
  strategic_value: ${strategic_value}
  investment_eur: ${investment}
  wacc: ${wacc}
  years: ${years}
  risk_factor: ${risk_factor}
outputs:
  npv_eur: ${npv}
  irr_pct: ${irr}
  payback_months: ${payback}
  risk_adjusted_value: ${risk_adjusted}
  confidence: "${confidence}"
EOF

printf '{"project":"%s","tenant":"%s","npv_eur":%s,"irr_pct":%s,"payback_months":%s,"risk_adjusted_value":%s,"confidence":"%s"}\n' \
  "$PROJECT" "$TENANT" "$npv" "$irr" "$payback" "$risk_adjusted" "$confidence"
