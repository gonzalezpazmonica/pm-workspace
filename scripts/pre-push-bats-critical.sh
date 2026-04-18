#!/usr/bin/env bash
# pre-push-bats-critical.sh — SPEC-SE-012 Module 3.
#
# Selective BATS runner: detects files staged or committed on the current
# branch (vs main), maps them to their related .bats tests, and runs ONLY
# those. Goal: fast signal on likely-affected tests before push without
# running the full 136-test suite.
#
# File → test mapping convention:
#   .claude/hooks/foo.sh        → tests/test-foo.bats OR tests/test-hook-foo.bats
#   scripts/foo.sh              → tests/test-foo.bats
#   .claude/skills/foo/SKILL.md → tests/test-skill-foo.bats
#   tests/test-foo.bats         → itself
#
# Usage:
#   pre-push-bats-critical.sh [--base main] [--quiet]
#
# Exit codes:
#   0  — all relevant tests passed (or no tests identified)
#   1  — at least one test failed
#   2  — usage error
#
# Ref: SPEC-SE-012 Module 3, ROADMAP.md §Tier 5
# Integration: optional gate in /pr-plan (Gate G6c, opt-in via
# PR_PLAN_ENABLE_CRITICAL_BATS=1).
#
# Safety: `set -uo pipefail`. Read-only (no git mutations).

set -uo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TESTS_DIR="$REPO_ROOT/tests"

BASE_BRANCH="main"
QUIET=0

usage() {
  cat <<EOF
Usage: $0 [--base BRANCH] [--quiet]

  --base BRANCH   Compare against this branch (default: main)
  --quiet         Suppress progress output

Maps changed files to .bats tests and runs only those. Much faster than
the full suite for incremental validation.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE_BRANCH="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; usage; exit 2 ;;
  esac
done

log() { [[ "$QUIET" -eq 0 ]] && echo "$@" || true; }

# ── Detect changed files ───────────────────────────────────────────────────

# Prefer diff vs base branch; fall back to staged if base unreachable.
changed_files=""
if git rev-parse --verify "origin/$BASE_BRANCH" >/dev/null 2>&1; then
  changed_files=$(git diff --name-only "origin/$BASE_BRANCH"...HEAD 2>/dev/null || echo "")
elif git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
  changed_files=$(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null || echo "")
else
  changed_files=$(git diff --cached --name-only 2>/dev/null || echo "")
fi

if [[ -z "$changed_files" ]]; then
  log "pre-push-bats: no changed files detected — nothing to test"
  exit 0
fi

log "pre-push-bats: $(echo "$changed_files" | wc -l) file(s) changed vs $BASE_BRANCH"

# ── Map files to tests ─────────────────────────────────────────────────────

map_file_to_test() {
  local f="$1"
  local bname
  case "$f" in
    tests/*.bats)
      echo "$f"
      ;;
    .claude/hooks/*.sh)
      bname=$(basename "$f" .sh)
      # Try exact name first, then hook-prefixed.
      [[ -f "$TESTS_DIR/test-$bname.bats" ]] && echo "tests/test-$bname.bats"
      [[ -f "$TESTS_DIR/test-hook-$bname.bats" ]] && echo "tests/test-hook-$bname.bats"
      ;;
    scripts/*.sh|scripts/*.py)
      bname=$(basename "$f")
      bname="${bname%.sh}"
      bname="${bname%.py}"
      [[ -f "$TESTS_DIR/test-$bname.bats" ]] && echo "tests/test-$bname.bats"
      ;;
    .claude/skills/*/SKILL.md|.claude/skills/*/DOMAIN.md)
      skill=$(echo "$f" | sed -E 's|.claude/skills/([^/]+)/.*|\1|')
      [[ -f "$TESTS_DIR/test-skill-$skill.bats" ]] && echo "tests/test-skill-$skill.bats"
      [[ -f "$TESTS_DIR/test-$skill.bats" ]] && echo "tests/test-$skill.bats"
      ;;
    .claude/agents/*.md)
      bname=$(basename "$f" .md)
      [[ -f "$TESTS_DIR/test-agent-$bname.bats" ]] && echo "tests/test-agent-$bname.bats"
      ;;
  esac
}

# ── Collect unique relevant tests ──────────────────────────────────────────

relevant_tests=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  test_path=$(map_file_to_test "$f")
  if [[ -n "$test_path" ]]; then
    relevant_tests+="$test_path"$'\n'
  fi
done <<< "$changed_files"

# Deduplicate.
unique_tests=$(echo -e "$relevant_tests" | grep -v '^$' | sort -u)

if [[ -z "$unique_tests" ]]; then
  log "pre-push-bats: no related tests mapped for the changed files"
  log "pre-push-bats: (this is OK for docs-only / config-only changes)"
  exit 0
fi

test_count=$(echo "$unique_tests" | wc -l)
log "pre-push-bats: running $test_count related .bats test file(s):"
while IFS= read -r t; do
  log "  - $t"
done <<< "$unique_tests"

# ── Execute ───────────────────────────────────────────────────────────────

failures=0
while IFS= read -r t; do
  [[ -z "$t" ]] && continue
  [[ ! -f "$REPO_ROOT/$t" ]] && continue
  if [[ "$QUIET" -eq 1 ]]; then
    bats "$REPO_ROOT/$t" >/dev/null 2>&1 || failures=$((failures+1))
  else
    bats "$REPO_ROOT/$t" || failures=$((failures+1))
  fi
done <<< "$unique_tests"

if [[ "$failures" -gt 0 ]]; then
  log ""
  log "pre-push-bats: ❌ $failures test file(s) failed"
  exit 1
fi

log ""
log "pre-push-bats: ✅ $test_count related test file(s) passed"
exit 0
