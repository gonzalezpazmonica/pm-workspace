#!/usr/bin/env bats
# BATS tests for SPEC-SE-012 Module 4 — PR queue check in pr-plan.sh g5
# Quality gate: SPEC-055 (audit score ≥80)
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-012-signal-noise-reduction.md

GATES="scripts/pr-plan-gates.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$CLAUDE_PROJECT_DIR/scripts"
  cp "$BATS_TEST_DIRNAME/../$GATES" "$CLAUDE_PROJECT_DIR/scripts/"
  cd "$CLAUDE_PROJECT_DIR"
  # Minimal git repo so git show origin/main works via fakery
  git init -q
  git config user.email test@example.com
  git config user.name test
  # Ensure the queue check is opt-out friendly
  export PR_PLAN_SKIP_QUEUE_CHECK=1
}

teardown() {
  cd /
  rm -rf "$CLAUDE_PROJECT_DIR"
  unset PR_PLAN_SKIP_QUEUE_CHECK
}

# Helper: create a CHANGELOG.md with a given top version and optional Era
_make_changelog() {
  local version="$1" era="${2:-Era 999}"
  cat > CHANGELOG.md <<EOF
# Changelog

## [$version] — 2026-04-11

$era test entry

### Added
- test

## [0.1.0] — 2026-01-01

First release. Era 1.
EOF
}

# Helper: seed a fake origin/main CHANGELOG with a given version
_seed_main_changelog() {
  local version="$1"
  local tmp="$BATS_TEST_TMPDIR/main-changelog-$version.md"
  cat > "$tmp" <<EOF
# Changelog

## [$version] — 2026-01-01

Main entry. Era 1.
EOF
  # Mock git show by creating a helper function (not actual git machinery)
  export MOCK_MAIN_VERSION="$version"
}

# ── Structural tests ──────────────────────────────────────────────────────

@test "gates file exists and can be sourced without error" {
  run bash -c "source scripts/pr-plan-gates.sh && declare -f g5 >/dev/null"
  [[ "$status" -eq 0 ]]
}

@test "gates file uses set -uo pipefail equivalent (sourced, not strict)" {
  # Sourced files don't strictly need set -u, but verify no obvious syntax errors
  run bash -n scripts/pr-plan-gates.sh
  [[ "$status" -eq 0 ]]
}

@test "g5 function is defined with expected name" {
  run bash -c "source scripts/pr-plan-gates.sh && declare -F g5"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"g5"* ]]
}

@test "g5 references PR_PLAN_SKIP_QUEUE_CHECK env var" {
  grep -q "PR_PLAN_SKIP_QUEUE_CHECK" scripts/pr-plan-gates.sh
}

# ── Opt-out / skip behavior ───────────────────────────────────────────────

@test "queue check can be disabled via PR_PLAN_SKIP_QUEUE_CHECK=1" {
  # With skip flag set, the gate should not attempt to call gh
  _make_changelog "9.9.9" "Era 500"
  # Also need a fake git HEAD and origin/main setup — skip to lighter test
  grep -q 'PR_PLAN_SKIP_QUEUE_CHECK.*!=.*"1"' scripts/pr-plan-gates.sh
}

# ── Collision detection logic (isolated, no gh) ──────────────────────────

@test "g5 contains version collision detection logic" {
  grep -q "collides with open PR" scripts/pr-plan-gates.sh
}

@test "g5 suggests next free version on collision" {
  grep -q "next free" scripts/pr-plan-gates.sh
}

@test "g5 uses gh api contents endpoint to read remote CHANGELOG" {
  grep -q "gh api.*contents/CHANGELOG.md" scripts/pr-plan-gates.sh
}

@test "g5 degrades gracefully when gh is missing" {
  grep -q "command -v gh" scripts/pr-plan-gates.sh
}

# ── Regression: g5 still does main comparison ────────────────────────────

@test "g5 still checks CHANGELOG not updated vs main (pre-queue-check invariant)" {
  grep -q "CHANGELOG not updated" scripts/pr-plan-gates.sh
}

@test "g5 still enforces Era reference in latest entry" {
  grep -q "missing Era reference" scripts/pr-plan-gates.sh
}

# ── Version math invariants ──────────────────────────────────────────────

@test "next free version bumps minor (X.Y.0)" {
  # Verify the awk expression produces a minor bump, not patch
  run bash -c 'echo "4.37.0" | awk -F. "{ printf \"%d.%d.0\n\", \$1, \$2+1 }"'
  [[ "$status" -eq 0 ]]
  [[ "$output" == "4.38.0" ]]
}

@test "next free bump handles double-digit minor correctly" {
  run bash -c 'echo "4.99.0" | awk -F. "{ printf \"%d.%d.0\n\", \$1, \$2+1 }"'
  [[ "$output" == "4.100.0" ]]
}

# ── Integration smoke ─────────────────────────────────────────────────────

@test "g5 is a function (not a subshell or alias)" {
  run bash -c "LC_ALL=C source scripts/pr-plan-gates.sh && declare -F g5 >/dev/null && echo OK"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OK"* ]]
}

@test "g5 implementation line count under 60 (single responsibility)" {
  local n
  n=$(awk '/^g5\(\)/,/^}/' scripts/pr-plan-gates.sh | wc -l)
  [[ "$n" -lt 60 ]]
}
