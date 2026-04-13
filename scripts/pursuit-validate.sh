#!/usr/bin/env bash
set -uo pipefail
# pursuit-validate.sh — SE-015: Validate pursuit directories
#
# Checks 8 failure modes in pipeline/pursuits/ directories:
#   1. Missing qualification before pursuit stage
#   2. Missing bid-decision before proposal stage
#   3. Incomplete BANT/MEDDIC scoring
#   4. Orphan pursuits >90d without stage change
#   5. Handoff missing for won pursuits
#   6. Team without solution-architect role
#   7. Duplicate OPP-IDs across tenant
#   8. Library references pointing at nonexistent assets
#
# Usage:
#   bash scripts/pursuit-validate.sh [pipeline-dir]
#   bash scripts/pursuit-validate.sh tenants/acme/pipeline
#   bash scripts/pursuit-validate.sh --summary   # counts only

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

errors=0
warnings=0
checked=0

log_error() { echo "ERROR: $*" >&2; (( errors++ )) || true; }
log_warn()  { echo "WARN:  $*" >&2; (( warnings++ )) || true; }
log_ok()    { echo "OK:    $*"; }

# Extract YAML frontmatter value from a .md file
fm_value() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null | grep -m1 "^${key}:" | sed "s/^${key}: *//" | tr -d '"' | tr -d "'"
}

# ── Main validation ─────────────────────────────────────────────────────────

validate_pursuit() {
  local pursuit_dir="$1"
  local pursuit_file="$pursuit_dir/pursuit.md"
  local opp_id
  opp_id=$(basename "$pursuit_dir")
  (( checked++ )) || true

  # Basic: pursuit.md must exist
  if [[ ! -f "$pursuit_file" ]]; then
    log_error "[$opp_id] Missing pursuit.md"
    return
  fi

  local stage
  stage=$(fm_value "$pursuit_file" "stage")

  # Check 1: Missing qualification before pursuit stage
  if [[ "$stage" == "pursuit" || "$stage" == "proposal" || "$stage" == "negotiation" ]]; then
    if [[ ! -f "$pursuit_dir/qualification.yaml" ]]; then
      log_error "[$opp_id] Stage=$stage but no qualification.yaml (gate: qualification required before pursuit)"
    fi
  fi

  # Check 2: Missing bid-decision before proposal stage
  if [[ "$stage" == "proposal" || "$stage" == "negotiation" ]]; then
    if [[ ! -f "$pursuit_dir/bid-decision.md" ]]; then
      log_error "[$opp_id] Stage=$stage but no bid-decision.md (gate: bid/no-bid required before proposal)"
    fi
  fi

  # Check 3: Incomplete BANT/MEDDIC scoring
  if [[ -f "$pursuit_dir/qualification.yaml" ]]; then
    local bant_fields meddic_fields
    bant_fields=$(grep -cE '^\s+(budget|authority|need|timing):' "$pursuit_dir/qualification.yaml" 2>/dev/null || echo 0)
    meddic_fields=$(grep -cE '^\s+(metrics|economic_buyer|decision_criteria|decision_process|identify_pain|champion):' "$pursuit_dir/qualification.yaml" 2>/dev/null || echo 0)
    if (( bant_fields < 4 )); then
      log_warn "[$opp_id] Incomplete BANT scoring ($bant_fields/4 dimensions)"
    fi
    if (( meddic_fields < 6 )); then
      log_warn "[$opp_id] Incomplete MEDDIC scoring ($meddic_fields/6 core dimensions)"
    fi
  fi

  # Check 4: Orphan pursuits >90d without stage change
  if [[ "$stage" != "won" && "$stage" != "lost" ]]; then
    local file_age_days
    if [[ "$(uname)" == "Darwin" ]]; then
      file_age_days=$(( ( $(date +%s) - $(stat -f %m "$pursuit_file") ) / 86400 ))
    else
      file_age_days=$(( ( $(date +%s) - $(stat -c %Y "$pursuit_file") ) / 86400 ))
    fi
    if (( file_age_days > 90 )); then
      log_warn "[$opp_id] Orphan pursuit: stage=$stage, last modified ${file_age_days}d ago (>90d threshold)"
    fi
  fi

  # Check 5: Handoff missing for won pursuits
  if [[ "$stage" == "won" ]]; then
    if [[ ! -f "$pursuit_dir/handoff.md" ]]; then
      log_error "[$opp_id] Stage=won but no handoff.md (sales→delivery handoff required)"
    fi
  fi

  # Check 6: Team without solution-architect role
  if grep -q "pursuit_team:" "$pursuit_file" 2>/dev/null; then
    if ! grep -qE "role:\s*\"?solution-architect" "$pursuit_file" 2>/dev/null; then
      log_warn "[$opp_id] Pursuit team missing solution-architect role"
    fi
  fi
}

# ── Check 7: Duplicate OPP-IDs ─────────────────────────────────────────────

check_duplicates() {
  local pipeline_dir="$1"
  local opp_ids=()

  while IFS= read -r -d '' pursuit_file; do
    local fmid
    fmid=$(fm_value "$pursuit_file" "opp_id")
    [[ -z "$fmid" ]] && continue
    opp_ids+=("$fmid")
  done < <(find "$pipeline_dir/pursuits" -name "pursuit.md" -print0 2>/dev/null)

  local dupes
  dupes=$(printf '%s\n' "${opp_ids[@]}" 2>/dev/null | sort | uniq -d)
  if [[ -n "$dupes" ]]; then
    while IFS= read -r dup; do
      log_error "Duplicate OPP-ID: $dup"
    done <<< "$dupes"
  fi
}

# ── Check 8: Library references ─────────────────────────────────────────────

check_library_refs() {
  local pipeline_dir="$1"
  local library_dir="$pipeline_dir/library"
  [[ -d "$library_dir" ]] || return 0

  while IFS= read -r -d '' md_file; do
    while IFS= read -r ref; do
      local target="$pipeline_dir/$ref"
      if [[ ! -f "$target" && ! -d "$target" ]]; then
        log_warn "[$(basename "$(dirname "$md_file")")] Library reference not found: $ref"
      fi
    done < <(grep -oP 'library/[^\s\)\"]+' "$md_file" 2>/dev/null || true)
  done < <(find "$pipeline_dir/pursuits" -name "*.md" -print0 2>/dev/null)
}

# ── Entry point ─────────────────────────────────────────────────────────────

main() {
  local pipeline_dir="${1:-}"
  local summary_mode=false

  if [[ "$pipeline_dir" == "--summary" ]]; then
    summary_mode=true
    pipeline_dir=""
  fi

  # Auto-detect pipeline directories if not specified
  if [[ -z "$pipeline_dir" ]]; then
    local found=false
    for candidate in "$REPO_ROOT"/tenants/*/pipeline "$REPO_ROOT"/projects/*/pipeline; do
      [[ -d "$candidate/pursuits" ]] || continue
      found=true
      pipeline_dir="$candidate"
      echo "Scanning: $pipeline_dir"
      run_checks "$pipeline_dir"
    done
    if [[ "$found" == false ]]; then
      echo "No pipeline directories found."
      echo "Expected: tenants/{tenant}/pipeline/pursuits/ or projects/{project}/pipeline/pursuits/"
      exit 0
    fi
  else
    if [[ ! -d "$pipeline_dir" ]]; then
      echo "Directory not found: $pipeline_dir" >&2
      exit 1
    fi
    run_checks "$pipeline_dir"
  fi

  # Summary
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Pursuit Validation (SE-015)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Pursuits checked:  $checked"
  echo "  Errors:            $errors"
  echo "  Warnings:          $warnings"
  if (( errors > 0 )); then
    echo "  Status:            FAIL"
    exit 1
  elif (( warnings > 0 )); then
    echo "  Status:            PASS (with warnings)"
    exit 0
  else
    echo "  Status:            PASS"
    exit 0
  fi
}

run_checks() {
  local pipeline_dir="$1"

  # Validate each pursuit
  if [[ -d "$pipeline_dir/pursuits" ]]; then
    while IFS= read -r -d '' pursuit_dir; do
      [[ -d "$pursuit_dir" ]] || continue
      validate_pursuit "$pursuit_dir"
    done < <(find "$pipeline_dir/pursuits" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    # Cross-pursuit checks
    check_duplicates "$pipeline_dir"
    check_library_refs "$pipeline_dir"
  fi
}

main "$@"
