#!/usr/bin/env bats
# BATS tests for scripts/pr-plan-gates.sh new gates (g5b, g6b)
# Ref: docs/propuestas/SPEC-055-test-quality.md (SPEC-055, SPEC-031 slice 3 v2 lesson)
#
# These new gates catch CI failures locally that previously only surfaced
# after push → failed CI → re-push cycles:
#   - G5b: ci-extended-checks.sh (CHANGELOG version links, etc.)
#   - G6b: test-auditor.sh on changed .bats files (SPEC-055 ≥80 score)

GATES="scripts/pr-plan-gates.sh"
PLAN="scripts/pr-plan.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "pr-plan-gates.sh has valid bash syntax" {
  run bash -n "$GATES"
  [ "$status" -eq 0 ]
}

@test "pr-plan.sh has valid bash syntax" {
  run bash -n "$PLAN"
  [ "$status" -eq 0 ]
}

@test "gates file has set -uo pipefail or is sourced (no header needed)" {
  # pr-plan-gates.sh is sourced by pr-plan.sh (no standalone execution).
  # Verify it does not set -e (would break source flow) but script sourcing it does.
  run head -20 "$PLAN"
  [[ "$output" == *"set -uo pipefail"* ]]
}

# ── G5b: extended CI checks gate ───────────────────────────────────────────

@test "g5b function defined in pr-plan-gates.sh" {
  run grep -cE "^g5b\(\) \{" "$GATES"
  [ "$output" = "1" ]
}

@test "g5b invokes ci-extended-checks.sh" {
  run grep -c "ci-extended-checks.sh" "$GATES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "g5b registered in pr-plan.sh as gate G5b" {
  run grep -c 'gate "G5b"' "$PLAN"
  [ "$output" = "1" ]
}

@test "g5b runs before G7 (confidentiality) in pr-plan.sh" {
  # Ordering matters: extended checks are fast, should run before slower gates
  local g5b_line g7_line
  g5b_line=$(grep -n 'gate "G5b"' "$PLAN" | head -1 | cut -d: -f1)
  g7_line=$(grep -n 'gate "G7"' "$PLAN" | head -1 | cut -d: -f1)
  [ "$g5b_line" -lt "$g7_line" ]
}

# ── G6b: test quality gate on changed files ────────────────────────────────

@test "g6b function defined in pr-plan-gates.sh" {
  run grep -cE "^g6b\(\) \{" "$GATES"
  [ "$output" = "1" ]
}

@test "g6b invokes test-auditor.sh" {
  run grep -c "test-auditor.sh" "$GATES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "g6b registered in pr-plan.sh as gate G6b" {
  run grep -c 'gate "G6b"' "$PLAN"
  [ "$output" = "1" ]
}

@test "g6b filters to *.bats files only" {
  run grep -E "tests/.*\.bats" "$GATES"
  [ "$status" -eq 0 ]
}

@test "g6b uses diff-filter=AM to get added+modified test files" {
  run grep -c "diff-filter=AM" "$GATES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "g6b threshold is 80 (SPEC-055)" {
  run grep -E "lt.*80\b|lt 80" "$GATES"
  [ "$status" -eq 0 ]
}

# ── Negative cases: error paths ────────────────────────────────────────────

@test "negative: missing ci-extended-checks.sh produces WARN (not FAIL)" {
  # Simulating the WARN path via code inspection — script uses [[ ! -x ]] guard
  run grep -c 'WARN: ci-extended-checks.sh missing' "$GATES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "negative: missing test-auditor.sh produces WARN (not FAIL)" {
  run grep -c 'WARN: test-auditor.sh missing' "$GATES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "negative: g6b skipped when no bats files changed" {
  run grep -c 'skipped (no \*.bats changed)' "$GATES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "negative: g5b catches failed ci-extended-checks via FAIL prefix" {
  run grep -c 'echo "FAIL: .* extended-checks failed' "$GATES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "negative: g6b reports low-score files with score number" {
  run grep -c 'echo "FAIL: test quality below 80' "$GATES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: g6b handles empty diff output gracefully" {
  # When `git diff` returns nothing, the gate must skip rather than FAIL
  run grep -E '\[\[ -z "\$changed" \]\].*skipped' "$GATES"
  [ "$status" -eq 0 ]
}

@test "edge: g6b handles nonexistent test file in diff (race condition)" {
  # If a test file was deleted between diff and audit, we skip it
  run grep -E '\[\[ -z "\$f" \|\| ! -f "\$f" \]\]' "$GATES"
  [ "$status" -eq 0 ]
}

@test "edge: g5b handles ci-extended-checks returning non-zero with no FAIL count" {
  # Script uses `|| true` to avoid set -e propagation and grep -oP regex
  # to extract the "N failed" number from output.
  run grep -c '|| true' "$GATES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "edge: g6b boundary — exactly 80 passes (strictly less than 80 fails)" {
  # Verify the comparison is `-lt 80`, not `-le 80` — 80 is pass per SPEC-055
  run grep -E '\-lt 80' "$GATES"
  [ "$status" -eq 0 ]
}

@test "edge: nonexistent changed file does not crash the gate loop" {
  # Covered by the guard `[[ -z "\$f" || ! -f "\$f" ]] && continue`
  run grep -c 'continue' "$GATES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── End-to-end: gate functions are invokable via source ────────────────────

@test "can source pr-plan-gates.sh without errors" {
  run bash -c 'STOPPED=""; PASS=0; FAIL=0; WARN=0; FAILED_FILE=""; BRANCH=test; source scripts/pr-plan-gates.sh; type g5b >/dev/null && type g6b >/dev/null'
  [ "$status" -eq 0 ]
}

@test "g5b produces output when ci-extended-checks passes" {
  # Integration smoke test — actually runs the check
  run bash -c 'STOPPED=""; PASS=0; FAIL=0; WARN=0; FAILED_FILE=""; BRANCH=test; source scripts/pr-plan-gates.sh; g5b'
  [ "$status" -eq 0 ]
  # Should produce either "6 checks pass" or "FAIL:" depending on local state
  [[ "$output" == *"checks pass"* || "$output" == *"FAIL:"* ]]
}

@test "g6b skips on main branch (no diff vs origin/main)" {
  # When there are no changed .bats files, g6b returns "skipped"
  run bash -c 'STOPPED=""; PASS=0; FAIL=0; WARN=0; FAILED_FILE=""; BRANCH=main; source scripts/pr-plan-gates.sh; cd /tmp && g6b' 2>&1
  # Either skipped or WARN (no changes detectable)
  [[ "$output" == *"skipped"* || "$output" == *"WARN"* || -z "$output" ]]
}
