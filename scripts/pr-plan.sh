#!/usr/bin/env bash
# pr-plan.sh — 10-gate pre-flight + sign + push + PR
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"; cd "$ROOT"

DRY=false; SKIP_PUSH=false; TITLE=""; BASE_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=true; shift ;; --skip-push) SKIP_PUSH=true; shift ;;
    --title) TITLE="$2"; shift 2 ;;
    --base) BASE_OVERRIDE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

BRANCH=$(git rev-parse --abbrev-ref HEAD)

# ── Resolve PR target (base) — fix for hardcoded origin/main ─────
# Priority:
#   1. --base remote/branch (explicit override)
#   2. SAVIA_PR_BASE env var (remote/branch)
#   3. gh pr view --json for current branch (auto-detect from open PR)
#   4. fallback origin/main (backward compat)
resolve_base() {
  if [[ -n "$BASE_OVERRIDE" ]]; then echo "$BASE_OVERRIDE"; return; fi
  if [[ -n "${SAVIA_PR_BASE:-}" ]]; then echo "$SAVIA_PR_BASE"; return; fi
  if command -v gh >/dev/null 2>&1; then
    local pr_info; pr_info=$(gh pr view --json baseRefName,baseRefRepository 2>/dev/null) || pr_info=""
    if [[ -n "$pr_info" ]]; then
      local base_repo base_branch base_owner
      base_repo=$(echo "$pr_info" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['baseRefRepository']['name'])" 2>/dev/null) || base_repo=""
      base_branch=$(echo "$pr_info" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['baseRefName'])" 2>/dev/null) || base_branch=""
      base_owner=$(echo "$pr_info" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['baseRefRepository']['owner']['login'])" 2>/dev/null) || base_owner=""
      if [[ -n "$base_repo" && -n "$base_branch" && -n "$base_owner" ]]; then
        # Find local remote matching the PR's base repo
        local rname; rname=$(git remote -v | grep -F "$base_owner/$base_repo" | head -1 | awk '{print $1}') || rname=""
        [[ -n "$rname" ]] && { echo "$rname/$base_branch"; return; }
      fi
    fi
  fi
  echo "origin/main"
}

BASE_REF=$(resolve_base)
BASE_REMOTE="${BASE_REF%%/*}"
BASE_BRANCH="${BASE_REF#*/}"
export BASE_REF BASE_REMOTE BASE_BRANCH
PASS=0; FAIL=0; WARN=0; STOPPED=""
FAILURE_FILE="output/pr-plan-failure.json"
mkdir -p output 2>/dev/null
sep() { printf '  %-4s %-28s %s\n' "$1" "$2" "$3"; }

# Anti-shortcut: record failure with root cause file
record_failure() {
  local gate="$1" reason="$2" failed_file="${3:-unknown}"
  printf '{"gate":"%s","reason":"%s","failed_file":"%s","commit":"%s","ts":"%s"}\n' \
    "$gate" "$reason" "$failed_file" "$(git rev-parse --short HEAD)" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo now)" > "$FAILURE_FILE"
}

source "$SCRIPT_DIR/pr-plan-gates.sh"

# ── Run gates ────────────────────────────────────────────────────
echo "------------------------------------------------------------"
echo "  PR Pre-Flight — $BRANCH"
echo "  Target — $BASE_REF"
echo "------------------------------------------------------------"
echo ""
gate "G0"  "Previous failure check" g0
gate "G1"  "Branch safety"         g1
gate "G2"  "Clean working tree"    g2
gate "G3"  "No merge conflicts"    g3
gate "G4"  "Divergence from main"  g4
gate "G5"  "CHANGELOG audit"       g5
gate "G5b" "Extended CI checks"    g5b
gate "G6"  "BATS tests"            g6
gate "G6b" "Test quality (changed)" g6b
gate "G7"  "Confidentiality scan"  g7
gate "G8"  "Documentation check"   g8
gate "G9"  "Zero project leakage"  g9
gate "G10" "CI validation"         g10
gate "G11" "PR natural-lang summary" g_summary
gate "G12" "Spec OpenCode plan" g_opencode_plan
gate "G13" "Scope-trace audit"  g13_scope_trace
gate "G14" "Skill catalog audit" g14_skill_catalog
echo ""
echo "------------------------------------------------------------"
if [[ -n "$STOPPED" ]]; then
  echo "  STOPPED at $STOPPED"
  echo "------------------------------------------------------------"
  bash "$SCRIPT_DIR/session-action-log.sh" log "pr-plan" "$BRANCH" "fail" "$STOPPED" >/dev/null 2>&1 || true
  bash "$SCRIPT_DIR/execution-supervisor.sh" "pr-plan" "$BRANCH" "$STOPPED" 2>&1 || true
  exit 1
fi
echo "  Result: $PASS PASS | $FAIL FAIL | $WARN WARN"
echo "------------------------------------------------------------"
$DRY && { echo -e "\n  --dry-run: no push."; exit 0; }

# Write sentinel — all gates passed, push-pr.sh can proceed
touch .pr-plan-ok

$SKIP_PUSH && { rm -f .pr-plan-ok; echo "  --skip-push: gates passed, no push."; exit 0; }

echo "  Pushing + PR..."
export SAVIA_PUSH_PR=1
PUSH_CMD=(bash scripts/push-pr.sh --skip-changelog --skip-ci --from-pr-plan --base "$BASE_REF")
[[ -n "$TITLE" ]] && PUSH_CMD+=(--title "$TITLE")
PR_OUT=$("${PUSH_CMD[@]}" 2>&1) || true
echo "$PR_OUT" | grep -E "(http|PR |Done)" | tail -3
if ! echo "$PR_OUT" | grep -qE "https://github.com/"; then
  record_failure "push-pr" "PR creation failed" "scripts/push-pr.sh"
  echo "  FAILURE recorded — fix scripts/push-pr.sh and rerun /pr-plan"
fi
echo "------------------------------------------------------------"
