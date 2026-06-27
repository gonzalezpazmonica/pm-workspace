#!/usr/bin/env bash
# scripts/loop-budget-check.sh
# SE-228 Slice 4 — Loop budget gate with kill switch
# Ref: docs/rules/domain/loop-budget-schema.md
#
# Usage:
#   loop-budget-check.sh --skill <name> [--report] [--dry-run]
#   loop-budget-check.sh --skill <name> --update-tokens N [--dry-run]
#
# Exit codes:
#   0 — budget OK (or --report/--help)
#   1 — budget exceeded / kill condition triggered / weekend pause
#   2 — usage error (missing required args)

set -uo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
SCRIPT_NAME="$(basename "$0")"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOOP_BUDGET_DIR="${LOOP_BUDGET_DIR:-$PROJECT_ROOT/output/loop-budget}"

SKILL=""
DO_REPORT=false
DO_UPDATE_TOKENS=false
UPDATE_TOKENS_N=0
DRY_RUN=false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
usage() {
  cat >&2 <<EOF
Usage:
  $SCRIPT_NAME --skill <name> [--report] [--dry-run]
  $SCRIPT_NAME --skill <name> --update-tokens N [--dry-run]
  $SCRIPT_NAME --help

Options:
  --skill <name>       Skill name; reads LOOP_BUDGET_DIR/<name>/loop-budget.md
  --report             Print budget summary and exit 0
  --update-tokens N    Add N tokens to tokens_used_today (resets counter if new day)
  --dry-run            Show what would happen without writing changes
  --help               Show this message and exit 0

Environment:
  LOOP_BUDGET_DIR      Override base directory (default: \$PROJECT_ROOT/output/loop-budget)
  PROJECT_ROOT         Repository root (auto-detected if not set)

Exit codes:
  0  Budget OK
  1  Budget exceeded / kill condition / weekend pause
  2  Usage error
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "$*"; }

# Parse a scalar YAML value from a loop-budget.md file
# parse_field <file> <field_name>
parse_field() {
  local file="$1"
  local field="$2"
  grep -m1 "^${field}:" "$file" 2>/dev/null \
    | sed 's/^[^:]*:[[:space:]]*//' \
    | tr -d '"' \
    | tr -d "'"
}

# Check if a kill_if condition is present in the file
has_kill_condition() {
  local file="$1"
  local condition="$2"
  grep -q "^[[:space:]]*-[[:space:]]*${condition}" "$file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      [[ -z "${2:-}" ]] && { echo "ERROR: --skill requires a value" >&2; exit 2; }
      SKILL="$2"; shift 2 ;;
    --report)
      DO_REPORT=true; shift ;;
    --update-tokens)
      [[ -z "${2:-}" ]] && { echo "ERROR: --update-tokens requires a numeric value" >&2; exit 2; }
      DO_UPDATE_TOKENS=true
      UPDATE_TOKENS_N="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=true; shift ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2; exit 2 ;;
  esac
done

# --skill is required for all operations
if [[ -z "$SKILL" ]]; then
  echo "ERROR: --skill is required" >&2
  usage
  exit 2
fi

# ---------------------------------------------------------------------------
# Load budget file
# ---------------------------------------------------------------------------
BUDGET_FILE="$LOOP_BUDGET_DIR/$SKILL/loop-budget.md"

if [[ ! -f "$BUDGET_FILE" ]]; then
  die "Budget file not found: $BUDGET_FILE"
fi

DAILY_TOKEN_CAP="$(parse_field "$BUDGET_FILE" "daily_token_cap")"
TOKENS_USED_TODAY="$(parse_field "$BUDGET_FILE" "tokens_used_today")"
PAUSE_ON_WEEKEND="$(parse_field "$BUDGET_FILE" "pause_on_weekend")"
LAST_RESET="$(parse_field "$BUDGET_FILE" "last_reset")"

# Provide safe defaults if fields are missing/empty
DAILY_TOKEN_CAP="${DAILY_TOKEN_CAP:-0}"
TOKENS_USED_TODAY="${TOKENS_USED_TODAY:-0}"
PAUSE_ON_WEEKEND="${PAUSE_ON_WEEKEND:-false}"
LAST_RESET="${LAST_RESET:-}"

TODAY="$(date +%Y-%m-%d)"

# ---------------------------------------------------------------------------
# --update-tokens: reset if new day, then increment
# ---------------------------------------------------------------------------
if [[ "$DO_UPDATE_TOKENS" == true ]]; then
  if [[ "$LAST_RESET" != "$TODAY" ]]; then
    # New day — reset counter
    if [[ "$DRY_RUN" == true ]]; then
      info "DRY-RUN: would reset tokens_used_today=0, last_reset=$TODAY (was: last_reset=$LAST_RESET, tokens=$TOKENS_USED_TODAY)"
    else
      sed -i "s/^tokens_used_today:.*/tokens_used_today: 0/" "$BUDGET_FILE"
      sed -i "s/^last_reset:.*/last_reset: \"$TODAY\"/" "$BUDGET_FILE"
    fi
    TOKENS_USED_TODAY=0
    LAST_RESET="$TODAY"
  fi

  NEW_TOTAL=$(( TOKENS_USED_TODAY + UPDATE_TOKENS_N ))

  if [[ "$DRY_RUN" == true ]]; then
    info "DRY-RUN: would update tokens_used_today from $TOKENS_USED_TODAY to $NEW_TOTAL"
  else
    sed -i "s/^tokens_used_today:.*/tokens_used_today: $NEW_TOTAL/" "$BUDGET_FILE"
    sed -i "s/^last_reset:.*/last_reset: \"$TODAY\"/" "$BUDGET_FILE"
    info "TOKENS UPDATED: $TOKENS_USED_TODAY -> $NEW_TOTAL (cap: $DAILY_TOKEN_CAP)"
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Handle new day: reset counter before cap check
# ---------------------------------------------------------------------------
if [[ -n "$LAST_RESET" && "$LAST_RESET" != "$TODAY" ]]; then
  if [[ "$DRY_RUN" == false ]]; then
    sed -i "s/^tokens_used_today:.*/tokens_used_today: 0/" "$BUDGET_FILE"
    sed -i "s/^last_reset:.*/last_reset: \"$TODAY\"/" "$BUDGET_FILE"
  fi
  TOKENS_USED_TODAY=0
fi

# ---------------------------------------------------------------------------
# Kill condition: ci_red_3d
# ---------------------------------------------------------------------------
if has_kill_condition "$BUDGET_FILE" "ci_red_3d"; then
  CI_STREAK_FILE="$LOOP_BUDGET_DIR/$SKILL/.loop-ci-red-streak"
  if [[ -f "$CI_STREAK_FILE" ]]; then
    CI_STREAK="$(cat "$CI_STREAK_FILE" 2>/dev/null | tr -d '[:space:]')"
    CI_STREAK="${CI_STREAK:-0}"
    if [[ "$CI_STREAK" -ge 3 ]]; then
      info "KILL: ci_red_3d triggered — CI red for ${CI_STREAK} consecutive days"
      exit 1
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Kill condition: weekend pause
# ---------------------------------------------------------------------------
if [[ "$PAUSE_ON_WEEKEND" == "true" ]]; then
  DAY_OF_WEEK="$(date +%u)"   # 1=Mon … 6=Sat 7=Sun
  if [[ "$DAY_OF_WEEK" -ge 6 ]]; then
    info "PAUSED: weekend"
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Kill condition: daily token cap
# ---------------------------------------------------------------------------
OVER_BUDGET=false
if [[ "$DAILY_TOKEN_CAP" -gt 0 ]] && [[ "$TOKENS_USED_TODAY" -ge "$DAILY_TOKEN_CAP" ]]; then
  OVER_BUDGET=true
fi

# ---------------------------------------------------------------------------
# --report
# ---------------------------------------------------------------------------
if [[ "$DO_REPORT" == true ]]; then
  if [[ "$OVER_BUDGET" == true ]]; then
    info "BUDGET EXCEEDED: tokens_used_today=$TOKENS_USED_TODAY >= daily_token_cap=$DAILY_TOKEN_CAP"
  else
    if [[ "$DAILY_TOKEN_CAP" -eq 0 ]]; then
      info "BUDGET OK: $TOKENS_USED_TODAY/unlimited tokens used"
    else
      info "BUDGET OK: $TOKENS_USED_TODAY/$DAILY_TOKEN_CAP tokens used"
    fi
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Gate check (default action)
# ---------------------------------------------------------------------------
if [[ "$OVER_BUDGET" == true ]]; then
  info "BUDGET EXCEEDED: tokens_used_today=$TOKENS_USED_TODAY >= daily_token_cap=$DAILY_TOKEN_CAP"
  exit 1
fi

# All checks passed
if [[ "$DAILY_TOKEN_CAP" -eq 0 ]]; then
  info "BUDGET OK: $TOKENS_USED_TODAY/unlimited tokens used"
else
  info "BUDGET OK: $TOKENS_USED_TODAY/$DAILY_TOKEN_CAP tokens used"
fi
exit 0
