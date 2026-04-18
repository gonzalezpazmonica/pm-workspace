#!/usr/bin/env bash
# pr-plan-queue-check.sh — SPEC-SE-012 Module 4.
#
# Prevents CHANGELOG version collisions across open PRs by cross-checking
# the local top version against the top version in every open PR branch
# before push. Target: eliminate the manual bump-retry cycle observed with
# real collisions (#515↔main, #517↔#518, and a similar case this sprint).
#
# Exit codes:
#   0  — no collision detected (or gracefully skipped)
#   1  — collision detected (blocks /pr-plan unless override)
#   2  — usage error
#
# Usage:
#   pr-plan-queue-check.sh [--local-version X.Y.Z] [--quiet]
#
# Environment:
#   PR_PLAN_SKIP_QUEUE_CHECK=1  — skip gracefully (CI, offline, gh missing)
#
# Ref: SPEC-SE-012 Module 4, ROADMAP.md §Tier 5
# Safety: `set -uo pipefail`. Read-only (no git mutations). Network opt-in
# via gh; if gh missing or fails → skip silently, never block.

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
CHANGELOG="$REPO_ROOT/CHANGELOG.md"

LOCAL_VERSION=""
QUIET=0

usage() {
  cat <<EOF
Usage: $0 [--local-version X.Y.Z] [--quiet]

Checks if the local CHANGELOG top version collides with any open PR's
CHANGELOG top version. Blocks if collision, suggests next free version.

  --local-version X.Y.Z  Override auto-detection
  --quiet                Suppress stdout, exit code only

Environment:
  PR_PLAN_SKIP_QUEUE_CHECK=1  Skip gracefully (CI, offline)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local-version) LOCAL_VERSION="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

log() { [[ "$QUIET" -eq 0 ]] && echo "$@" || true; }

# ── Graceful exits ─────────────────────────────────────────────────────────

if [[ "${PR_PLAN_SKIP_QUEUE_CHECK:-0}" == "1" ]]; then
  log "queue-check: skipped (PR_PLAN_SKIP_QUEUE_CHECK=1)"
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  log "queue-check: skipped (gh CLI not installed)"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  log "queue-check: skipped (jq not installed)"
  exit 0
fi

# ── Detect local version ───────────────────────────────────────────────────

if [[ -z "$LOCAL_VERSION" ]]; then
  if [[ ! -f "$CHANGELOG" ]]; then
    log "queue-check: no CHANGELOG.md, skipping"
    exit 0
  fi
  LOCAL_VERSION=$(grep -m1 -oE '^## \[([0-9]+\.[0-9]+\.[0-9]+)\]' "$CHANGELOG" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
fi

if [[ -z "$LOCAL_VERSION" ]]; then
  log "queue-check: no top version found in CHANGELOG, skipping"
  exit 0
fi

log "queue-check: local top version = $LOCAL_VERSION"

# ── Fetch open PRs ─────────────────────────────────────────────────────────

current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Use gh with timeout protection — if network fails, skip.
prs_json=$(timeout 10 gh pr list --state open --limit 30 --json number,headRefName 2>/dev/null || echo "[]")
pr_count=$(echo "$prs_json" | jq 'length')

if [[ "$pr_count" -eq 0 ]]; then
  log "queue-check: no open PRs to compare against"
  exit 0
fi

log "queue-check: scanning $pr_count open PRs..."

collision_found=0
highest_version="$LOCAL_VERSION"

while read -r pr_num branch; do
  [[ -z "$pr_num" || -z "$branch" ]] && continue
  [[ "$branch" == "$current_branch" ]] && continue

  # Fetch CHANGELOG from that branch (timeout-bounded).
  content=$(timeout 8 gh api "repos/:owner/:repo/contents/CHANGELOG.md?ref=$branch" --jq '.content // ""' 2>/dev/null | tr -d '\n' | base64 -d 2>/dev/null || echo "")

  if [[ -z "$content" ]]; then
    continue
  fi

  remote_version=$(echo "$content" | grep -m1 -oE '^## \[([0-9]+\.[0-9]+\.[0-9]+)\]' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  [[ -z "$remote_version" ]] && continue

  # Track highest version across the queue for suggestion.
  if [[ "$(printf '%s\n%s\n' "$remote_version" "$highest_version" | sort -V | tail -1)" == "$remote_version" ]]; then
    highest_version="$remote_version"
  fi

  if [[ "$remote_version" == "$LOCAL_VERSION" ]]; then
    collision_found=1
    log "queue-check: ❌ COLLISION — PR #$pr_num ($branch) also claims v$remote_version"
  fi
done < <(echo "$prs_json" | jq -r '.[] | "\(.number) \(.headRefName)"')

if [[ "$collision_found" -eq 1 ]]; then
  # Suggest next free version: bump minor of the highest observed.
  IFS='.' read -r maj min pat <<< "$highest_version"
  next_minor=$(( min + 1 ))
  suggested="${maj}.${next_minor}.0"
  log ""
  log "queue-check: FAIL — v$LOCAL_VERSION collides. Suggestion: bump to v$suggested (next free after queue max v$highest_version)."
  exit 1
fi

log "queue-check: ✅ no collisions with $pr_count open PRs"
exit 0
