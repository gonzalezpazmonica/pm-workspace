#!/usr/bin/env bats
# Tests for PR review scaling gates (g11)
# Ref: docs/rules/domain/risk-escalation.md, scoring-curves.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/scripts/pr-plan-gates.sh"
  BRANCH="test-branch"
  FAILURE_FILE="/tmp/test-pr-failure-$$"
  STOPPED=""
  FAILED_FILE=""
  TMPDIR_PR=$(mktemp -d)
  export MOCK_STAT_LINE=""
  export MOCK_REVPARSE_FAIL=""
  git() {
    if [[ "$1" == "rev-parse" && "$2" == "origin/main" ]]; then
      [[ -n "$MOCK_REVPARSE_FAIL" ]] && return 1
      return 0
    fi
    if [[ "$1" == "diff" ]]; then
      echo "$MOCK_STAT_LINE"
      return 0
    fi
    command git "$@"
  }
  export -f git
  rm -f output/risk-score.json
}
teardown() {
  rm -f output/risk-score.json "$FAILURE_FILE"
  rm -rf "$TMPDIR_PR"
  unset -f git 2>/dev/null || true
}

@test "g11 XS for 23 lines" {
  MOCK_STAT_LINE=" 2 files changed, 15 insertions(+), 8 deletions(-)"
  run g11
  [[ "$output" == *"XS (23 lines)"* ]]
  [[ "$output" != *"FAIL:"* ]]
}

@test "g11 STANDARD for 187 lines" {
  MOCK_STAT_LINE=" 5 files changed, 120 insertions(+), 67 deletions(-)"
  run g11
  [[ "$output" == *"STANDARD (187 lines)"* ]]
  [[ "$output" == *"WARN:"* ]]
}

@test "g11 ENHANCED for 542 lines" {
  MOCK_STAT_LINE=" 10 files changed, 342 insertions(+), 200 deletions(-)"
  run g11
  [[ "$output" == *"ENHANCED (542 lines)"* ]]
}

@test "g11 FULL for 1847 lines" {
  MOCK_STAT_LINE=" 20 files changed, 1200 insertions(+), 647 deletions(-)"
  run g11
  [[ "$output" == *"FULL (1847 lines)"* ]]
  [[ "$output" == *"Consider splitting"* ]]
}

@test "g11 0 lines nothing to review" {
  MOCK_STAT_LINE=""
  run g11
  [[ "$output" == *"0 lines"* ]]
  [[ "$output" != *"FAIL:"* ]]
}

@test "g11 boundary: 50 lines is STANDARD" {
  MOCK_STAT_LINE=" 1 file changed, 30 insertions(+), 20 deletions(-)"
  run g11
  [[ "$output" == *"STANDARD (50 lines)"* ]]
}

@test "g11 boundary: 49 lines is XS" {
  MOCK_STAT_LINE=" 1 file changed, 30 insertions(+), 19 deletions(-)"
  run g11
  [[ "$output" == *"XS (49 lines)"* ]]
}

@test "g11 boundary: 301 lines is ENHANCED" {
  MOCK_STAT_LINE=" 3 files changed, 200 insertions(+), 101 deletions(-)"
  run g11
  [[ "$output" == *"ENHANCED (301 lines)"* ]]
}

@test "g11 boundary: 1001 lines is FULL" {
  MOCK_STAT_LINE=" 8 files changed, 600 insertions(+), 401 deletions(-)"
  run g11
  [[ "$output" == *"FULL (1001 lines)"* ]]
}
@test "g11 origin/main unreachable" {
  MOCK_REVPARSE_FAIL=1
  run g11
  [[ "$output" == *"unknown (origin/main unreachable)"* ]]
}

@test "g11 risk score escalates tier" {
  MOCK_STAT_LINE=" 5 files changed, 120 insertions(+), 67 deletions(-)"
  mkdir -p output
  echo '{"score": 62}' > output/risk-score.json
  run g11
  [[ "$output" == *"ENHANCED"* ]]
  [[ "$output" == *"risk score 62 escalated from STANDARD"* ]]
}

@test "g11 risk score cannot escalate down" {
  MOCK_STAT_LINE=" 20 files changed, 1200 insertions(+), 647 deletions(-)"
  mkdir -p output
  echo '{"score": 10}' > output/risk-score.json
  run g11
  [[ "$output" == *"FULL"* ]]
}

@test "g11 never emits FAIL" {
  MOCK_STAT_LINE=" 50 files changed, 5000 insertions(+), 5000 deletions(-)"
  run g11
  [[ "$output" != *"FAIL:"* ]]
}

@test "g11 handles malformed stat line gracefully" {
  MOCK_STAT_LINE="not a valid stat line"
  run g11
  # Should not crash
  [[ "$output" == *"0 lines"* ]] || [[ "$output" == *"lines"* ]]
}

@test "g11 handles invalid risk score JSON" {
  MOCK_STAT_LINE=" 5 files changed, 120 insertions(+), 67 deletions(-)"
  mkdir -p output
  echo 'not json' > output/risk-score.json
  run g11
  [[ "$output" == *"STANDARD"* ]]
}

@test "g11 boundary: 300 lines is still STANDARD" {
  MOCK_STAT_LINE=" 3 files changed, 200 insertions(+), 100 deletions(-)"
  run g11
  [[ "$output" == *"STANDARD (300 lines)"* ]]
}

@test "push-pr.sh has set -euo pipefail safety header" {
  grep -q "set -euo pipefail" scripts/push-pr.sh
}

@test "g11 outputs review level for small PR" {
  MOCK_STAT_LINE=" 1 file changed, 10 insertions(+), 5 deletions(-)"
  run g11
  [ "$status" -eq 0 ]
  [[ "$output" == *"XS"* ]]
}
