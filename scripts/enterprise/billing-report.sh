#!/usr/bin/env bash
set -uo pipefail
# billing-report.sh — SE-018 Project Billing (IFRS 15)
#
# Genera informe de facturación por proyecto/tenant.
#
# Usage:
#   bash scripts/enterprise/billing-report.sh \
#     --tenant SLUG [--project SLUG] [--month YYYY-MM] [--json]
#
# Output: {total_invoiced, total_paid, outstanding, recognition_rate, milestones: [...]}
#
# Exit codes: 0 ok | 2 usage error
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-018-project-billing.md

TENANT=""
PROJECT=""
MONTH=""
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)  TENANT="$2";  shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --month)   MONTH="$2";   shift 2 ;;
    --json)    JSON_MODE=true; shift ;;
    --help|-h)
      grep -E '^#( |$)' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$TENANT" ]]; then
  echo "ERROR: --tenant is required" >&2
  exit 2
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

# Collect billing files
if [[ -n "$PROJECT" ]]; then
  billing_files=("${REPO_ROOT}/tenants/${TENANT}/projects/${PROJECT}/billing.jsonl")
else
  mapfile -t billing_files < <(find "${REPO_ROOT}/tenants/${TENANT}/projects" -name "billing.jsonl" 2>/dev/null || true)
fi

total_amount=0
total_invoiced=0
total_paid=0
total_recognized=0
milestone_count=0
milestones_json="["
first=true

for billing_file in "${billing_files[@]}"; do
  [[ -f "$billing_file" ]] || continue

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    # Apply month filter if provided
    if [[ -n "$MONTH" ]]; then
      rec_at=$(echo "$line" | grep -o '"recorded_at":"[^"]*"' | cut -d'"' -f4 || echo "")
      if [[ "${rec_at:0:7}" != "$MONTH" ]]; then
        continue
      fi
    fi

    amt=$(echo "$line" | grep -o '"amount_eur":[0-9.]*' | cut -d: -f2 || echo "0")
    stat=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "pending")
    recognized=$(echo "$line" | grep -o '"revenue_recognized_eur":[0-9.]*' | cut -d: -f2 || echo "0")
    ms=$(echo "$line" | grep -o '"milestone":"[^"]*"' | cut -d'"' -f4 || echo "")
    proj=$(echo "$line" | grep -o '"project":"[^"]*"' | cut -d'"' -f4 || echo "")

    total_amount=$(awk -v a="$total_amount" -v b="${amt:-0}" 'BEGIN{printf "%.2f", a+b}')
    total_recognized=$(awk -v a="$total_recognized" -v b="${recognized:-0}" 'BEGIN{printf "%.2f", a+b}')

    case "$stat" in
      invoiced) total_invoiced=$(awk -v a="$total_invoiced" -v b="${amt:-0}" 'BEGIN{printf "%.2f", a+b}') ;;
      paid)     total_paid=$(awk -v a="$total_paid" -v b="${amt:-0}" 'BEGIN{printf "%.2f", a+b}') ;;
    esac

    milestone_count=$((milestone_count + 1))

    if [[ "$JSON_MODE" == true ]]; then
      if [[ "$first" == false ]]; then
        milestones_json="${milestones_json},"
      fi
      milestones_json="${milestones_json}${line}"
      first=false
    fi
  done < "$billing_file"
done

milestones_json="${milestones_json}]"

outstanding=$(awk -v inv="$total_invoiced" -v paid="$total_paid" 'BEGIN{printf "%.2f", inv-paid}')
recognition_rate=$(awk -v rec="$total_recognized" -v tot="$total_amount" '
BEGIN{ if (tot>0) printf "%.1f", rec/tot*100; else printf "0.0" }')

if [[ "$JSON_MODE" == true ]]; then
  printf '{"tenant":"%s","total_amount_eur":%s,"total_invoiced_eur":%s,"total_paid_eur":%s,"outstanding_eur":%s,"recognition_rate_pct":%s,"milestone_count":%d,"milestones":%s}\n' \
    "$TENANT" "$total_amount" "$total_invoiced" "$total_paid" "$outstanding" "$recognition_rate" "$milestone_count" "$milestones_json"
else
  echo "Billing Report — Tenant: ${TENANT}${PROJECT:+, Project: $PROJECT}${MONTH:+, Month: $MONTH}"
  echo "  Total amount:     ${total_amount} EUR"
  echo "  Total invoiced:   ${total_invoiced} EUR"
  echo "  Total paid:       ${total_paid} EUR"
  echo "  Outstanding:      ${outstanding} EUR"
  echo "  Recognition rate: ${recognition_rate}%"
  echo "  Milestones:       ${milestone_count}"
fi
