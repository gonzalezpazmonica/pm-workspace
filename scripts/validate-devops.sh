#!/usr/bin/env bash
# =============================================================================
# validate-devops.sh — Validate Azure DevOps project against pm-workspace
# =============================================================================
# Audits process template, work item types, states, fields, backlog config
# and sprint setup. Returns JSON report with PASS/FAIL/WARN per check.
#
# Usage: ./scripts/validate-devops.sh --project NAME [--team TEAM] [--output FILE]
# Requires: curl, jq, PAT file at $AZURE_DEVOPS_PAT_FILE
# Exit: 0 no FAIL · 1 at least one FAIL · 2 usage/configuration error (no report)
# The PAT travels to curl through stdin (-K -), never through argv or logs.
# =============================================================================

set -euo pipefail

# ── CONSTANTS ────────────────────────────────────────────────────────────────
ORG_URL="${AZURE_DEVOPS_ORG_URL:-https://dev.azure.com/MI-ORGANIZACION}"
PAT_FILE="${AZURE_DEVOPS_PAT_FILE:-$HOME/.azure/devops-pat}"
API_VERSION="${AZURE_DEVOPS_API_VERSION:-7.1}"
PROJECT="" TEAM="" OUTPUT_FILE="" AUTH_B64="" P_ENC="" T_ENC=""

# ── HELPERS ──────────────────────────────────────────────────────────────────
log()   { echo "[$(date '+%H:%M:%S')] $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 2; }

urlenc() { jq -rn --arg s "$1" '$s | @uri'; }

# api_get URL → prints the JSON body and returns 0 on HTTP 2xx with valid JSON.
# Otherwise prints the reason ("HTTP 401", "network error (curl exit 7)",
# "invalid JSON response") and returns 1. Callers must treat 1 as FAIL.
api_get() {
  local raw rc=0 code body
  raw=$(printf 'header = "Authorization: Basic %s"\n' "$AUTH_B64" \
    | curl -sS -K - -H "Accept: application/json" -w $'\n%{http_code}' "$1" 2>/dev/null) || rc=$?
  if [[ $rc -ne 0 ]]; then echo "network error (curl exit $rc)"; return 1; fi
  code="${raw##*$'\n'}"
  if [[ "$raw" == *$'\n'* ]]; then body="${raw%$'\n'*}"; else body=""; fi
  if [[ ! "$code" =~ ^2[0-9][0-9]$ ]]; then echo "HTTP $code"; return 1; fi
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$body"; then
    echo "invalid JSON response"; return 1
  fi
  printf '%s\n' "$body"
}

check_dependencies() {
  command -v curl >/dev/null 2>&1 || error "curl not found"
  command -v jq   >/dev/null 2>&1 || error "jq not found. Install: apt install jq / brew install jq"
  [[ "$ORG_URL" != *MI-ORGANIZACION* ]] || error "AZURE_DEVOPS_ORG_URL not configured (placeholder value)"
  [[ -f "$PAT_FILE" ]] || error "PAT file not found at $PAT_FILE"
  [[ -r "$PAT_FILE" ]] || error "PAT file not readable at $PAT_FILE"
  local pat
  pat="$(cat "$PAT_FILE")"
  pat="${pat//[$'\r\n\t ']/}"
  [[ -n "$pat" ]] || error "PAT file is empty at $PAT_FILE"
  # base64 wraps at 76 columns; an 84-char PAT would split the header in two.
  AUTH_B64="$(printf ':%s' "$pat" | base64 | tr -d '\n')"
}

need_value() { [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || error "$1 requires a value. Use --help for usage."; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) need_value "$@"; PROJECT="$2"; shift 2 ;;
      --team)    need_value "$@"; TEAM="$2";    shift 2 ;;
      --output)  need_value "$@"; OUTPUT_FILE="$2"; shift 2 ;;
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

Exit codes:
  0  no check FAILed (PASS/WARN only)
  1  at least one check FAILed (API errors and unreadable responses count as FAIL)
  2  usage or configuration error (no report)

Environment variables:
  AZURE_DEVOPS_ORG_URL      Organization URL (required, no placeholder)
  AZURE_DEVOPS_PAT_FILE     Path to PAT file (default: ~/.azure/devops-pat)
  AZURE_DEVOPS_API_VERSION  API version (default: 7.1)

Examples:
  $0 --project "PM-Workspace" --team "PM-Workspace Team"
  $0 --project "MyProject" --output output/devops-validation.json
HELP
}

# ── MAIN ─────────────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  check_dependencies
  P_ENC="$(urlenc "$PROJECT")"
  T_ENC="$(urlenc "$TEAM")"

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
    result=$($fn 2>/dev/null) || true
    # A check that crashes or emits anything but one result object is a FAIL.
    if ! jq -e 'type == "object" and (.status | IN("PASS","WARN","FAIL"))' >/dev/null 2>&1 <<<"$result"; then
      log "$fn produced no valid result; recorded as FAIL"
      result=$(jq -n --arg f "${fn#check_}" '{check:$f,status:"FAIL",message:"Check crashed unexpectedly"}')
    fi
    RESULTS=$(jq -c --argjson r "$result" '. + [$r]' <<<"$RESULTS")
  done

  local REPORT
  REPORT=$(jq -n \
    --arg p "$PROJECT" --arg t "$TEAM" --arg org "$ORG_URL" \
    --argjson checks "$RESULTS" \
    '{project:$p,team:$t,org:$org,timestamp:(now|todate),
      summary:{total:($checks|length),
               pass:([$checks[]|select(.status=="PASS")]|length),
               fail:([$checks[]|select(.status=="FAIL")]|length),
               warn:([$checks[]|select(.status=="WARN")]|length)},
      checks:$checks}')

  if [[ -n "$OUTPUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    jq '.' <<<"$REPORT" > "$OUTPUT_FILE"
    log "Report saved to $OUTPUT_FILE"
  fi

  jq '.' <<<"$REPORT"
  [[ "$(jq '.summary.fail' <<<"$REPORT")" -eq 0 ]] || exit 1
}

main "$@"
