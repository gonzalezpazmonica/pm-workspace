#!/usr/bin/env bash
# ci-failure-tracker.sh — Track CI pipeline failures for signal/noise analysis
# SPEC-SE-012 Module 2
#
# Usage:
#   ci-failure-tracker.sh record <pr-number>       Append current CI state of PR to log
#   ci-failure-tracker.sh health [--days N]        Show failure rates from log
#   ci-failure-tracker.sh top [--days N]           Top-5 recurring causes
#
# Log: $CLAUDE_PROJECT_DIR/output/ci-runs.jsonl (append-only, N3 local)

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_FILE="$PROJECT_DIR/output/ci-runs.jsonl"
mkdir -p "$(dirname "$LOG_FILE")"

die() { echo "❌ $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "requires: $1"; }

cmd_record() {
  local pr="${1:-}"
  [[ -z "$pr" ]] && die "usage: ci-failure-tracker.sh record <pr-number>"
  need gh
  need jq

  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Fetch PR status; exit 0 even if no checks yet
  local json
  json=$(gh pr view "$pr" --json number,headRefName,statusCheckRollup 2>/dev/null) || {
    echo "⚠️  Could not fetch PR #$pr (may not exist or gh not authed)" >&2
    return 1
  }

  local branch
  branch=$(echo "$json" | jq -r '.headRefName')

  local count=0
  while IFS=$'\t' read -r check workflow conclusion url; do
    [[ -z "$check" ]] && continue
    jq -cn --arg ts "$now" \
           --argjson pr "$pr" \
           --arg branch "$branch" \
           --arg check "$check" \
           --arg workflow "$workflow" \
           --arg conclusion "$conclusion" \
           --arg url "$url" \
      '{ts:$ts, pr:$pr, branch:$branch, workflow:$workflow, check:$check, conclusion:$conclusion, job_url:$url}' \
      >> "$LOG_FILE"
    count=$((count + 1))
  done < <(echo "$json" | jq -r '
    .statusCheckRollup[]?
    | select(.conclusion != null)
    | [.name, (.workflowName // "-"), .conclusion, (.detailsUrl // "-")]
    | @tsv')

  echo "✓ Recorded $count checks for PR #$pr (branch: $branch) → $LOG_FILE"
}

_filter_by_days() {
  # Stdin: JSONL log. Stdout: entries within last N days.
  local days="$1"
  [[ "$days" == "0" ]] && { cat; return; }
  local cutoff
  cutoff=$(date -u -d "$days days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
           date -u -v-"${days}d" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
  [[ -z "$cutoff" ]] && { cat; return; }
  jq -c --arg cutoff "$cutoff" 'select(.ts >= $cutoff)'
}

cmd_health() {
  local days=30
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --days) days="${2:-30}"; shift 2 ;;
      *) shift ;;
    esac
  done
  need jq

  if [[ ! -f "$LOG_FILE" ]]; then
    echo "ℹ️  No log yet at $LOG_FILE. Run: ci-failure-tracker.sh record <pr>"
    return 0
  fi

  local total failures
  total=$(_filter_by_days "$days" < "$LOG_FILE" | wc -l | tr -d ' ')
  failures=$(_filter_by_days "$days" < "$LOG_FILE" | jq -c 'select(.conclusion == "FAILURE")' | wc -l | tr -d ' ')

  if [[ "$total" == "0" ]]; then
    echo "ℹ️  No records in last $days days."
    return 0
  fi

  local fail_pct=0
  [[ "$total" -gt 0 ]] && fail_pct=$(( failures * 100 / total ))

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 CI Health — last $days days"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Total records ..... $total"
  echo "  Failures .......... $failures ($fail_pct%)"
  echo ""
  echo "  By check:"
  _filter_by_days "$days" < "$LOG_FILE" | jq -r '[.check, .conclusion] | @tsv' | \
    awk -F'\t' '
      { total[$1]++; if ($2 == "FAILURE") fail[$1]++ }
      END {
        for (c in total) {
          f = fail[c] + 0
          pct = (f * 100) / total[c]
          printf "    %-40s %3d runs  %3d fail  (%2d%%)\n", c, total[c], f, pct
        }
      }' | sort -k4 -nr
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

cmd_top() {
  local days=30
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --days) days="${2:-30}"; shift 2 ;;
      *) shift ;;
    esac
  done
  need jq

  [[ ! -f "$LOG_FILE" ]] && { echo "ℹ️  No log yet."; return 0; }

  echo "🔥 Top recurring failures (last $days days):"
  _filter_by_days "$days" < "$LOG_FILE" | \
    jq -r 'select(.conclusion == "FAILURE") | .check' | \
    sort | uniq -c | sort -rn | head -5 | \
    awk '{ printf "  %3d× %s\n", $1, substr($0, index($0,$2)) }'
}

case "${1:-}" in
  record)  shift; cmd_record "$@" ;;
  health)  shift; cmd_health "$@" ;;
  top)     shift; cmd_top "$@" ;;
  "")      die "usage: ci-failure-tracker.sh {record|health|top} [args]" ;;
  *)       die "unknown command: $1" ;;
esac
