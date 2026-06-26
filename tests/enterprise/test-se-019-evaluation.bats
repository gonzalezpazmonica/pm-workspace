#!/usr/bin/env bats
# test-se-019-evaluation.bats — SE-019 Project Evaluation
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-019-project-evaluation.md

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  EVALUATION="${REPO_ROOT}/scripts/enterprise/project-evaluation.sh"
  BILLING_MILESTONE="${REPO_ROOT}/scripts/enterprise/billing-milestone.sh"
  SOW_CREATE="${REPO_ROOT}/scripts/enterprise/sow-create.sh"
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR REPO_ROOT
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "SE-019: project-evaluation.sh exists and is executable" {
  [[ -f "$EVALUATION" ]]
  [[ -x "$EVALUATION" ]]
}

@test "SE-019: project-evaluation.sh fails without required args" {
  run bash "$EVALUATION"
  [ "$status" -eq 2 ]
}

@test "SE-019: project-evaluation.sh creates evaluation.md" {
  local tenant="eval-$$"
  local project="eval-proj"

  # Create project dir
  mkdir -p "${TEST_TMPDIR}/tenants/${tenant}/projects/${project}"

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${EVALUATION}' \
    --project '${project}' --tenant '${tenant}'"
  [ "$status" -eq 0 ]

  local eval_file="${TEST_TMPDIR}/tenants/${tenant}/projects/${project}/evaluation/evaluation.md"
  [[ -f "$eval_file" ]]
  grep -q "project:" "$eval_file"
  grep -q "tenant:" "$eval_file"
}

@test "SE-019: project-evaluation.sh reads billing data" {
  local tenant="billing-eval-$$"
  local project="bproj"

  # Create billing milestones
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${BILLING_MILESTONE}' \
    --project '${project}' --tenant '${tenant}' \
    --milestone 'M1' --amount 25000 --date '2026-05-01' --status paid" >/dev/null 2>&1
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${BILLING_MILESTONE}' \
    --project '${project}' --tenant '${tenant}' \
    --milestone 'M2' --amount 35000 --date '2026-06-01' --status invoiced" >/dev/null 2>&1

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${EVALUATION}' \
    --project '${project}' --tenant '${tenant}'"
  [ "$status" -eq 0 ]

  local eval_file="${TEST_TMPDIR}/tenants/${tenant}/projects/${project}/evaluation/evaluation.md"
  grep -q "milestone_count: 2" "$eval_file"
  grep -q "total_billed_eur: 60000" "$eval_file"
}

@test "SE-019: project-evaluation.sh reads SOW data" {
  local tenant="sow-eval-$$"
  local project="sowproj"

  # Create SOW first
  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${SOW_CREATE}' \
    --project '${project}' --tenant '${tenant}' --template basic" >/dev/null 2>&1

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${EVALUATION}' \
    --project '${project}' --tenant '${tenant}'"
  [ "$status" -eq 0 ]

  local eval_file="${TEST_TMPDIR}/tenants/${tenant}/projects/${project}/evaluation/evaluation.md"
  grep -q "sow_present: found" "$eval_file"
}

@test "SE-019: project-evaluation.sh fails for nonexistent project dir" {
  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${EVALUATION}' \
    --project 'ghost-project' --tenant 'nobody'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "SE-019: evaluation.md contains all required sections" {
  local tenant="sections-$$"
  local project="sec-proj"
  mkdir -p "${TEST_TMPDIR}/tenants/${tenant}/projects/${project}"

  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${EVALUATION}' \
    --project '${project}' --tenant '${tenant}'" >/dev/null

  local eval_file="${TEST_TMPDIR}/tenants/${tenant}/projects/${project}/evaluation/evaluation.md"
  grep -qi "## Objectives Met" "$eval_file"
  grep -qi "## Velocity" "$eval_file"
  grep -qi "## Lessons Learned" "$eval_file"
  grep -qi "## NPS Score" "$eval_file"
}
