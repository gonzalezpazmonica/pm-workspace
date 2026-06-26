#!/usr/bin/env bats
# test-se-034-activation-plan.bats — SE-034 Daily Agent Activation Plan
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-034-agent-activation-plan.md

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  DAILY_PLAN="${REPO_ROOT}/scripts/enterprise/daily-activation-plan.sh"
  PLAN_REVIEW="${REPO_ROOT}/scripts/enterprise/activation-plan-review.sh"
  export DAILY_PLAN PLAN_REVIEW

  PLANS_DIR="${TEST_TMPDIR}/activation-plans"
  mkdir -p "$PLANS_DIR"
  export PLANS_DIR

  TEST_DATE="2026-06-24"
  export TEST_DATE
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: daily-activation-plan.sh exists and is executable ────────────────

@test "daily-activation-plan.sh exists and is executable" {
  [[ -f "$DAILY_PLAN" ]]
  [[ -x "$DAILY_PLAN" ]]
}

# ── Test 2: plan is generated in output/activation-plans/ ────────────────────

@test "daily-activation-plan.sh generates plan in output/activation-plans/" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$DAILY_PLAN' --date '$TEST_DATE'"
  [ "$status" -eq 0 ]

  PLAN_FILE="${TEST_TMPDIR}/output/activation-plans/${TEST_DATE}.md"
  # Also accept the real output dir path
  [[ -f "$PLAN_FILE" ]] || [[ -f "${REPO_ROOT}/output/activation-plans/${TEST_DATE}.md" ]]
}

# ── Test 3: plan contains Token Budget section ────────────────────────────────

@test "daily-activation-plan.sh plan contains Token Budget section" {
  # Generate plan to a known temp dir
  mkdir -p "${TEST_TMPDIR}/output/activation-plans"
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$DAILY_PLAN' --date '$TEST_DATE'"
  [ "$status" -eq 0 ]

  PLAN_FILE="${TEST_TMPDIR}/output/activation-plans/${TEST_DATE}.md"
  [[ -f "$PLAN_FILE" ]]
  grep -q 'Token Budget' "$PLAN_FILE"
}

# ── Test 4: plan contains agent sequence section ──────────────────────────────

@test "daily-activation-plan.sh plan contains agent sequence" {
  mkdir -p "${TEST_TMPDIR}/output/activation-plans"
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$DAILY_PLAN' --date '$TEST_DATE'"
  [ "$status" -eq 0 ]

  PLAN_FILE="${TEST_TMPDIR}/output/activation-plans/${TEST_DATE}.md"
  [[ -f "$PLAN_FILE" ]]
  grep -q 'Agent Sequence\|Priority Queue\|Activation Plan' "$PLAN_FILE"
}

# ── Test 5: activation-plan-review.sh exists and is executable ───────────────

@test "activation-plan-review.sh exists and is executable" {
  [[ -f "$PLAN_REVIEW" ]]
  [[ -x "$PLAN_REVIEW" ]]
}

# ── Test 6: activation-plan-review.sh with --approve exits 0 ─────────────────

@test "activation-plan-review.sh --approve exits 0 on valid plan" {
  mkdir -p "${TEST_TMPDIR}/output/activation-plans"
  # First generate a plan
  bash -c "REPO_ROOT='${TEST_TMPDIR}' '$DAILY_PLAN' --date '$TEST_DATE'" >/dev/null 2>&1

  PLAN_FILE="${TEST_TMPDIR}/output/activation-plans/${TEST_DATE}.md"
  [[ -f "$PLAN_FILE" ]]

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' '$PLAN_REVIEW' --date '$TEST_DATE' --approve"
  [ "$status" -eq 0 ]
}
