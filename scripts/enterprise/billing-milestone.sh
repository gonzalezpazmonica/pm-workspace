#!/usr/bin/env bash
set -uo pipefail
# billing-milestone.sh — SE-018 Project Billing (IFRS 15)
#
# Registra un milestone de facturación en billing.jsonl.
#
# Usage:
#   bash scripts/enterprise/billing-milestone.sh \
#     --project SLUG --tenant SLUG \
#     --milestone NAME --amount EUR --date DATE \
#     [--status pending|invoiced|paid]
#
# Appends to: tenants/{tenant}/projects/{slug}/billing.jsonl
# Calcula: revenue_recognized (IFRS 15 % of completion)
#
# Exit codes: 0 ok | 1 error | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-018-project-billing.md

PROJECT=""
TENANT=""
MILESTONE=""
AMOUNT=""
DATE=""
STATUS="pending"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)   PROJECT="$2";   shift 2 ;;
    --tenant)    TENANT="$2";    shift 2 ;;
    --milestone) MILESTONE="$2"; shift 2 ;;
    --amount)    AMOUNT="$2";    shift 2 ;;
    --date)      DATE="$2";      shift 2 ;;
    --status)    STATUS="$2";    shift 2 ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PROJECT" || -z "$TENANT" || -z "$MILESTONE" || -z "$AMOUNT" || -z "$DATE" ]]; then
  echo "ERROR: --project, --tenant, --milestone, --amount, and --date are required" >&2
  exit 2
fi

case "$STATUS" in
  pending|invoiced|paid) ;;
  *) echo "ERROR: --status must be pending|invoiced|paid" >&2; exit 2 ;;
esac

if ! [[ "$AMOUNT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "ERROR: --amount must be a positive number" >&2
  exit 2
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROJECT_DIR="${REPO_ROOT}/tenants/${TENANT}/projects/${PROJECT}"
BILLING_FILE="${PROJECT_DIR}/billing.jsonl"

mkdir -p "$PROJECT_DIR"

# Calculate cumulative total from existing milestones for POC
total_amount=0
total_invoiced=0
total_paid=0

if [[ -f "$BILLING_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    amt=$(echo "$line" | grep -o '"amount_eur":[0-9.]*' | cut -d: -f2 || echo "0")
    stat=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "")
    total_amount=$(awk -v a="$total_amount" -v b="${amt:-0}" 'BEGIN{printf "%.2f", a+b}')
    case "$stat" in
      invoiced) total_invoiced=$(awk -v a="$total_invoiced" -v b="${amt:-0}" 'BEGIN{printf "%.2f", a+b}') ;;
      paid)     total_paid=$(awk -v a="$total_paid" -v b="${amt:-0}" 'BEGIN{printf "%.2f", a+b}') ;;
    esac
  done < "$BILLING_FILE"
fi

# Add current milestone to total
new_total=$(awk -v a="$total_amount" -v b="$AMOUNT" 'BEGIN{printf "%.2f", a+b}')

# IFRS 15 POC: revenue recognized = cumulative amount / total estimated
# For simplicity, use running total as recognition basis
revenue_recognized=$(awk -v amt="$AMOUNT" -v total="$new_total" '
BEGIN {
  if (total > 0) printf "%.2f", amt / total * amt
  else printf "0.00"
}')

RECORDED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Append milestone record to billing.jsonl
printf '{"recorded_at":"%s","milestone":"%s","amount_eur":%s,"date":"%s","status":"%s","revenue_recognized_eur":%s,"project":"%s","tenant":"%s"}\n' \
  "$RECORDED_AT" "$MILESTONE" "$AMOUNT" "$DATE" "$STATUS" "$revenue_recognized" "$PROJECT" "$TENANT" \
  >> "$BILLING_FILE"

echo "Milestone recorded: ${BILLING_FILE}"
echo "  milestone:          ${MILESTONE}"
echo "  amount:             ${AMOUNT} EUR"
echo "  date:               ${DATE}"
echo "  status:             ${STATUS}"
echo "  revenue_recognized: ${revenue_recognized} EUR"
