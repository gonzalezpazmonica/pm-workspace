#!/usr/bin/env bash
# =============================================================================
# validate-devops.sh — Validate Azure DevOps project against pm-workspace
# =============================================================================
# Audits process template, work item types, states, fields, backlog config
# and sprint setup. Returns JSON report with PASS/FAIL/WARN per check.
#
# Usage: ./scripts/validate-devops.sh --project NAME --team TEAM [--output FILE]
# Requires: curl, jq, PAT file at $AZURE_DEVOPS_PAT_FILE
# =============================================================================

set -euo pipefail

# ── CONSTANTS ────────────────────────────────────────────────────────────────
ORG_URL="${AZURE_DEVOPS_ORG_URL:-https://dev.azure.com/MI-ORGANIZACION}"
PAT_FILE="${AZURE_DEVOPS_PAT_FILE:-$HOME/.azure/devops-pat}"
API_VERSION="${AZURE_DEVOPS_API_VERSION:-7.1}"
OUTPUT_DIR="${OUTPUT_DIR:-./output}"
PROJECT="" TEAM="" OUTPUT_FILE="" PROJECT_ID=""

# ── HELPERS ──────────────────────────────────────────────────────────────────
log()   { echo "[$(date '+%H:%M:%S')] $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 1; }

auth_header() {
  echo "Authorization: Basic $(echo -n ":$(cat "$PAT_FILE")" | base64)"
}

api_get() {
  curl -s -H "$(auth_header)" -H "Content-Type: application/json" "$1"
}

check_dependencies() {
  command -v curl >/dev/null 2>&1 || error "curl not found"
  command -v jq   >/dev/null 2>&1 || error "jq not found. Install: apt install jq / brew install jq"
  [[ -f "$PAT_FILE" ]] || error "PAT file not found at $PAT_FILE"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) PROJECT="$2"; shift 2 ;;
      --team)    TEAM="$2";    shift 2 ;;
      --output)  OUTPUT_FILE="$2"; shift 2 ;;
      --help|-h) show_help; exit 0 ;;
      *) error "Unknown argument: $1. Use --help for usage." ;;
    esac
  done
  [[ -n "$PROJECT" ]] || error "Required: --project NAME"
  [[ -n "$TEAM" ]]    || TEAM="$PROJECT Team"
}

show_help() {
  cat <<HELP
Usage: $0 --project NAME [--team TEAM] [--output FILE]

Validates Azure DevOps project configuration against pm-workspace
ideal Agile requirements. Returns JSON report.

Options:
  --project NAME   Azure DevOps project name (required)
  --team TEAM      Team name (default: "{project} Team")
  --output FILE    Save JSON report to file
  --help           Show this help

Checks performed:
  1. PAT connectivity       5. Work item states
  2. Project exists          6. Required fields per type
  3. Process template        7. Backlog configuration
  4. Work item types         8. Sprint/iteration setup

Environment variables:
  AZURE_DEVOPS_ORG_URL      Organization URL
  AZURE_DEVOPS_PAT_FILE     Path to PAT file (default: ~/.azure/devops-pat)
  AZURE_DEVOPS_API_VERSION  API version (default: 7.1)

Examples:
  $0 --project "PM-Workspace" --team "PM-Workspace Team"
  $0 --project "MyProject" --output output/devops-validation.json
HELP
}

# ── MAIN ─────────────────────────────────────────────────────────────────────
main() {
  check_dependencies
  parse_args "$@"

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=validate-devops-checks.sh
  source "$SCRIPT_DIR/validate-devops-checks.sh"

  log "Validating Azure DevOps: project=$PROJECT team=$TEAM org=$ORG_URL"

  local RESULTS="[]"
  local checks=(check_connectivity check_project check_process check_types
                check_states check_fields check_backlog check_iterations)

  for fn in "${checks[@]}"; do
    log "Running $fn..."
    local result
    result=$($fn 2>/dev/null || jq -n --arg f "$fn" \
      '{check:$f,status:"FAIL",message:"Check crashed unexpectedly"}')
    RESULTS=$(echo "$RESULTS" | jq --argjson r "$result" '. + [$r]')
  done

  local pass fail warn
  pass=$(echo "$RESULTS" | jq '[.[] | select(.status=="PASS")] | length')
  fail=$(echo "$RESULTS" | jq '[.[] | select(.status=="FAIL")] | length')
  warn=$(echo "$RESULTS" | jq '[.[] | select(.status=="WARN")] | length')

  local REPORT
  REPORT=$(jq -n \
    --arg p "$PROJECT" --arg t "$TEAM" --arg org "$ORG_URL" \
    --argjson pass "$pass" --argjson fail "$fail" --argjson warn "$warn" \
    --argjson checks "$RESULTS" \
    '{project:$p,team:$t,org:$org,timestamp:(now|todate),
      summary:{total:($pass+$fail+$warn),pass:$pass,fail:$fail,warn:$warn},
      checks:$checks}')

  if [[ -n "$OUTPUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    echo "$REPORT" | jq '.' > "$OUTPUT_FILE"
    log "Report saved to $OUTPUT_FILE"
  fi

  echo "$REPORT" | jq '.'
}

main "$@"
