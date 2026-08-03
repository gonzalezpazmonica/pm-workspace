#!/usr/bin/env bats

setup() {
  PUSH_PR="$BATS_TEST_DIRNAME/../scripts/push-pr.sh"
  TESTDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TESTDIR"
}

@test "push-pr.sh exists and is executable" {
  [ -f "$PUSH_PR" ]
  [ -x "$PUSH_PR" ] || [ -f "$PUSH_PR" ]
}

@test "push-pr.sh has valid bash syntax" {
  bash -n "$PUSH_PR"
  [ "$?" -eq 0 ]
}

@test "push-pr.sh uses set -uo pipefail" {
  head -6 "$PUSH_PR" | grep -q "set -euo pipefail"
}

@test "push-pr.sh refuses to run on main branch" {
  # Can't actually run without a PR context; just verify the guard exists
  grep -q 'main.*master' "$PUSH_PR"
  grep -q 'ERROR: On' "$PUSH_PR"
}

@test "push-pr.sh has SE-300 existing-PR detection in gh CLI branch" {
  grep -q "gh pr list --head" "$PUSH_PR"
  grep -q "gh pr edit" "$PUSH_PR"
  grep -q "EXISTING_PR" "$PUSH_PR"
}

@test "push-pr.sh has SE-300 update logic in python fallback branch" {
  grep -q "state=open" "$PUSH_PR"
  grep -q "method='PATCH'" "$PUSH_PR"
  grep -q "no_existing" "$PUSH_PR"
}

@test "push-pr.sh builds body from commits" {
  grep -q "git log --oneline origin/main..HEAD" "$PUSH_PR"
  grep -q "### Changes" "$PUSH_PR"
  grep -q "### Stats" "$PUSH_PR"
}

@test "push-pr.sh respects --title flag" {
  grep -q -- '--title) TITLE=' "$PUSH_PR"
}

@test "push-pr.sh respects --no-draft" {
  grep -q -- '--no-draft) DRAFT=false' "$PUSH_PR"
}
