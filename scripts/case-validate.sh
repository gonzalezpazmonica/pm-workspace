#!/usr/bin/env bash
set -uo pipefail
# case-validate.sh — SE-016: Validate business case directories
#
# Checks 6 failure modes in valuation/ directories:
#   1. Missing assumptions source
#   2. Stale assumptions >90d
#   3. Risk without probability or impact
#   4. Benefit schedule without review dates
#   5. Cost variance exceeding threshold without alert
#   6. Duplicate case IDs across tenant
#
# Usage:
#   bash scripts/case-validate.sh [valuation-dir]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

errors=0
warnings=0
checked=0

log_error() { echo "ERROR: $*" >&2; (( errors++ )) || true; }
log_warn()  { echo "WARN:  $*" >&2; (( warnings++ )) || true; }

fm_value() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null | grep -m1 "^${key}:" | sed "s/^${key}: *//" | tr -d '"' | tr -d "'"
}

validate_case() {
  local val_dir="$1"
  local case_file="$val_dir/business-case.md"
  local case_id
  case_id=$(basename "$(dirname "$val_dir")")/valuation
  (( checked++ )) || true

  if [[ ! -f "$case_file" ]]; then
    log_error "[$case_id] Missing business-case.md"
    return
  fi

  local bc_id
  bc_id=$(fm_value "$case_file" "case_id")

  # Check 1: Missing assumptions source
  if [[ -f "$val_dir/assumptions.yaml" ]]; then
    local nosource
    nosource=$(grep -c "source:" "$val_dir/assumptions.yaml" 2>/dev/null || echo 0)
    local total_assumptions
    total_assumptions=$(grep -c "id:" "$val_dir/assumptions.yaml" 2>/dev/null || echo 0)
    if (( total_assumptions > 0 && nosource < total_assumptions )); then
      log_warn "[${bc_id:-$case_id}] Assumptions without source field ($nosource/$total_assumptions have source)"
    fi
  fi

  # Check 2: Stale assumptions >90d
  if [[ -f "$val_dir/assumptions.yaml" ]]; then
    local today_epoch
    today_epoch=$(date +%s)
    while IFS= read -r date_line; do
      local validated_date
      validated_date=$(echo "$date_line" | grep -oP '\d{4}-\d{2}-\d{2}' || true)
      if [[ -n "$validated_date" ]]; then
        local val_epoch
        val_epoch=$(date -d "$validated_date" +%s 2>/dev/null || echo 0)
        if (( val_epoch > 0 )); then
          local age_days=$(( (today_epoch - val_epoch) / 86400 ))
          if (( age_days > 90 )); then
            log_warn "[${bc_id:-$case_id}] Stale assumption (last validated ${age_days}d ago, >90d threshold)"
            break
          fi
        fi
      fi
    done < <(grep "last_validated:" "$val_dir/assumptions.yaml" 2>/dev/null)
  fi

  # Check 3: Risk without probability or impact
  if [[ -f "$val_dir/risk-register.yaml" ]]; then
    local risks_total risks_with_prob risks_with_impact
    risks_total=$(grep -c "id:" "$val_dir/risk-register.yaml" 2>/dev/null) || risks_total=0
    risks_with_prob=$(grep -c "probability:" "$val_dir/risk-register.yaml" 2>/dev/null) || risks_with_prob=0
    risks_with_impact=$(grep -c "impact_eur:" "$val_dir/risk-register.yaml" 2>/dev/null) || risks_with_impact=0
    if (( risks_total > 0 )); then
      if (( risks_with_prob < risks_total )); then
        log_error "[${bc_id:-$case_id}] Risk(s) without probability ($risks_with_prob/$risks_total)"
      fi
      if (( risks_with_impact < risks_total )); then
        log_error "[${bc_id:-$case_id}] Risk(s) without impact_eur ($risks_with_impact/$risks_total)"
      fi
    fi
  fi

  # Check 4: Benefit schedule without review dates
  if [[ -f "$val_dir/benefit-schedule.yaml" ]]; then
    if ! grep -q "review_date\|review_at\|review_90d\|review_180d\|review_365d" "$val_dir/benefit-schedule.yaml" 2>/dev/null; then
      log_warn "[${bc_id:-$case_id}] Benefit schedule without review dates"
    fi
  fi

  # Check 5: Cost variance exceeding threshold without alert
  local status
  status=$(fm_value "$case_file" "status")
  if [[ "$status" == "active" ]]; then
    local cost_status
    cost_status=$(sed -n '/^---$/,/^---$/p' "$case_file" 2>/dev/null | grep -A3 "cost:" | grep "status:" | awk '{print $2}' | tr -d '"' || echo "")
    local cost_pct
    cost_pct=$(sed -n '/^---$/,/^---$/p' "$case_file" 2>/dev/null | grep -A3 "cost:" | grep "current_pct:" | awk '{print $2}' | tr -d '"' || echo "0")
    if [[ "$cost_pct" =~ ^[0-9]+$ ]] && (( cost_pct > 30 )) && [[ "$cost_status" != "red" ]]; then
      log_error "[${bc_id:-$case_id}] Cost variance ${cost_pct}% exceeds 30% but alert status is not 'red'"
    fi
  fi
}

# Check 6: Duplicate case IDs
check_duplicate_cases() {
  local search_root="$1"
  local case_ids=()

  while IFS= read -r -d '' case_file; do
    local cid
    cid=$(fm_value "$case_file" "case_id")
    [[ -z "$cid" ]] && continue
    case_ids+=("$cid")
  done < <(find "$search_root" -name "business-case.md" -print0 2>/dev/null)

  local dupes
  dupes=$(printf '%s\n' "${case_ids[@]}" 2>/dev/null | sort | uniq -d)
  if [[ -n "$dupes" ]]; then
    while IFS= read -r dup; do
      log_error "Duplicate case ID: $dup"
    done <<< "$dupes"
  fi
}

main() {
  local val_dir="${1:-}"

  if [[ -z "$val_dir" ]]; then
    local found=false
    for candidate in "$REPO_ROOT"/tenants/*/projects/*/valuation; do
      [[ -d "$candidate" ]] || continue
      found=true
      echo "Scanning: $candidate"
      validate_case "$candidate"
    done
    for tenant_dir in "$REPO_ROOT"/tenants/*/; do
      [[ -d "$tenant_dir" ]] && check_duplicate_cases "$tenant_dir"
    done
    if [[ "$found" == false ]]; then
      echo "No valuation directories found."
      echo "Expected: tenants/{tenant}/projects/{project}/valuation/"
      exit 0
    fi
  else
    if [[ ! -d "$val_dir" ]]; then
      echo "Directory not found: $val_dir" >&2
      exit 1
    fi
    validate_case "$val_dir"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Business Case Validation (SE-016)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Cases checked:   $checked"
  echo "  Errors:          $errors"
  echo "  Warnings:        $warnings"
  if (( errors > 0 )); then
    echo "  Status:          FAIL"
    exit 1
  elif (( warnings > 0 )); then
    echo "  Status:          PASS (with warnings)"
    exit 0
  else
    echo "  Status:          PASS"
    exit 0
  fi
}

main "$@"
