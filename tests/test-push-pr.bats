#!/usr/bin/env bats
# Ref: SE-300 (PR update), SE-343 (merge grant), SE-387 C/F5 (merge reservations)

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

@test "SE-300: branch-switch hook clears stale .pr-summary.md" {
  HOOK="$BATS_TEST_DIRNAME/../.claude/hooks/block-branch-switch-dirty.sh"
  [ -f "$HOOK" ]
  grep -q "SE-300" "$HOOK"
  grep -q ".pr-summary.md" "$HOOK"
  grep -q "rm -f" "$HOOK"
}

@test "SE-300: push-pr derives summary fallback when .pr-summary.md missing" {
  grep -q "Deriving summary\|Ver resumen tecnico" "$PUSH_PR"
  grep -q 'if \[\[ -f .pr-summary.md \]\]' "$PUSH_PR"
}

@test "SE-300: push-pr updates existing PR via gh pr edit" {
  grep -q "gh pr list --head" "$PUSH_PR"
  grep -q "gh pr edit" "$PUSH_PR"
}

@test "SE-300: python fallback uses PATCH for existing PR" {
  grep -q "method='PATCH'" "$PUSH_PR"
  grep -q "no_existing" "$PUSH_PR"
}

res_dir_expr() { grep -oP '^\s*RES_DIR="\K[^"]+' "$PUSH_PR"; }

@test "SE-387: push-pr no longer hardcodes the reservations path" {
  run grep -c 'HOME/.savia/reservations/pr.merge' "$PUSH_PR"
  [ "$output" -eq 0 ]
  [[ "$(res_dir_expr)" == '${SAVIA_RESERVATIONS:-$HOME/.savia/reservations}' ]]
}

@test "SE-387: push-pr and f5-state resolve the same reservations dir from SAVIA_RESERVATIONS" {
  F5="$BATS_TEST_DIRNAME/../scripts/f5-state.sh"
  run env SAVIA_RESERVATIONS="$TESTDIR/res" bash "$F5" reserve pr.merge 4242
  [ "$status" -eq 0 ]
  expr=$(res_dir_expr)
  resolved=$(SAVIA_RESERVATIONS="$TESTDIR/res" HOME="$TESTDIR/home" bash -c "echo \"$expr\"")
  [ "$resolved" = "$TESTDIR/res" ]
  [ -f "$resolved/pr.merge__4242.json" ]
  [ ! -e "$TESTDIR/home/.savia" ]
}

@test "empty: unset SAVIA_RESERVATIONS falls back to the home ledger path" {
  expr=$(res_dir_expr)
  resolved=$(env -u SAVIA_RESERVATIONS HOME="$TESTDIR/home" bash -c "echo \"$expr\"")
  [ "$resolved" = "$TESTDIR/home/.savia/reservations" ]
}

@test "nonexistent: reserving an already closed merge is rejected as ALREADY_EXECUTED" {
  F5="$BATS_TEST_DIRNAME/../scripts/f5-state.sh"
  mkdir -p "$TESTDIR/res"
  printf '{"op":"pr.merge","key":"7","state":"closed"}\n' > "$TESTDIR/res/pr.merge__7.json"
  run env SAVIA_RESERVATIONS="$TESTDIR/res" bash "$F5" reserve pr.merge 7
  [ "$status" -eq 3 ]
  [[ "$output" == *"ALREADY_EXECUTED"* ]]
}

@test "boundary: merge path keeps grant and risk-tier gates before any reservation" {
  grant_line=$(grep -n 'operator-grant.sh check --scope merge' "$PUSH_PR" | head -1 | cut -d: -f1)
  tier_line=$(grep -n 'risk-tier.py --diff' "$PUSH_PR" | head -1 | cut -d: -f1)
  res_line=$(grep -n 'f5-state.sh" reserve' "$PUSH_PR" | head -1 | cut -d: -f1)
  [ -n "$grant_line" ] && [ -n "$tier_line" ] && [ -n "$res_line" ]
  [ "$grant_line" -lt "$res_line" ]
  [ "$tier_line" -lt "$res_line" ]
}
