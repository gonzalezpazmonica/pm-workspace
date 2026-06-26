#!/usr/bin/env bats
# test-se-018-billing.bats — SE-018 Project Billing (IFRS 15)
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-018-project-billing.md

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  BILLING_MILESTONE="${REPO_ROOT}/scripts/enterprise/billing-milestone.sh"
  BILLING_REPORT="${REPO_ROOT}/scripts/enterprise/billing-report.sh"
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR REPO_ROOT
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── billing-milestone.sh ────────────────────────────────────────────────────

@test "SE-018: billing-milestone.sh exists and is executable" {
  [[ -f "$BILLING_MILESTONE" ]]
  [[ -x "$BILLING_MILESTONE" ]]
}

@test "SE-018: billing-milestone.sh fails without required args" {
  run bash "$BILLING_MILESTONE"
  [ "$status" -eq 2 ]
}

@test "SE-018: billing-milestone.sh creates billing.jsonl with correct fields" {
  local tenant="acme-$$"
  local project="erp-proj"

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${BILLING_MILESTONE}' \
    --project '${project}' \
    --tenant '${tenant}' \
    --milestone 'M1-kickoff' \
    --amount 30000 \
    --date '2026-06-01' \
    --status invoiced"
  [ "$status" -eq 0 ]

  local billing_file="${TEST_TMPDIR}/tenants/${tenant}/projects/${project}/billing.jsonl"
  [[ -f "$billing_file" ]]
  grep -q '"milestone":"M1-kickoff"' "$billing_file"
  grep -q '"amount_eur":30000' "$billing_file"
  grep -q '"status":"invoiced"' "$billing_file"
  grep -q '"revenue_recognized_eur"' "$billing_file"
}

@test "SE-018: billing-milestone.sh rejects invalid status" {
  run bash "$BILLING_MILESTONE" \
    --project p --tenant t --milestone m --amount 1000 --date 2026-01-01 --status "unknown"
  [ "$status" -eq 2 ]
  [[ "$output" == *"pending|invoiced|paid"* ]]
}

@test "SE-018: billing-milestone.sh appends multiple milestones" {
  local tenant="multi-$$"
  local project="multi-proj"

  for i in 1 2 3; do
    bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${BILLING_MILESTONE}' \
      --project '${project}' --tenant '${tenant}' \
      --milestone 'M${i}' --amount $((i * 10000)) --date '2026-0${i}-01' --status pending" \
      >/dev/null 2>&1
  done

  local billing_file="${TEST_TMPDIR}/tenants/${tenant}/projects/${project}/billing.jsonl"
  line_count=$(wc -l < "$billing_file")
  [[ "$line_count" -eq 3 ]]
}

@test "SE-018: billing-milestone.sh rejects non-numeric amount" {
  run bash "$BILLING_MILESTONE" \
    --project p --tenant t --milestone m --amount "abc" --date 2026-01-01
  [ "$status" -eq 2 ]
}

# ── billing-report.sh ───────────────────────────────────────────────────────

@test "SE-018: billing-report.sh exists and is executable" {
  [[ -f "$BILLING_REPORT" ]]
  [[ -x "$BILLING_REPORT" ]]
}

@test "SE-018: billing-report.sh fails without --tenant" {
  run bash "$BILLING_REPORT"
  [ "$status" -eq 2 ]
}

@test "SE-018: billing-report.sh returns JSON with all fields" {
  local tenant="report-$$"
  local project="rpt-proj"

  bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${BILLING_MILESTONE}' \
    --project '${project}' --tenant '${tenant}' \
    --milestone 'M1' --amount 50000 --date '2026-06-01' --status paid" >/dev/null 2>&1

  run bash -c "REPO_ROOT='${TEST_TMPDIR}' bash '${BILLING_REPORT}' \
    --tenant '${tenant}' --project '${project}' --json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total_paid_eur"* ]]
  [[ "$output" == *"outstanding_eur"* ]]
  [[ "$output" == *"recognition_rate_pct"* ]]
  [[ "$output" == *"milestone_count"* ]]
}
