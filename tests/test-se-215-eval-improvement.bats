#!/usr/bin/env bats
# tests/test-se-215-eval-improvement.bats — SE-215: eval-improvement-suggest.sh
# Ref: docs/propuestas/SE-215-eval-driven-improvement-loop.md

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------
setup() {
  TMPDIR="$(mktemp -d)"
  export PROJECT_ROOT="$TMPDIR"
  mkdir -p "${TMPDIR}/output"
  mkdir -p "${TMPDIR}/scripts"

  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/eval-improvement-suggest.sh"
  export SCRIPT

  # Helper: create a minimal passing eval report
  _make_pass_report() {
    cat > "${TMPDIR}/output/eval-report-20991231.md" <<'REPORT'
# Eval Report — 20991231

> SE-204: Evaluation harness structural validation
> Agent filter: all
> Threshold: 80%

## Summary

| Metric | Value |
|---|---|
| Total eval cases | 3 |
| Passed | 3 |
| Failed | 0 |
| Score | 100% |
| Threshold | 80% |
| Result | PASS |

## Results by Agent

### sdd-spec-writer

Score: 3/3 (100%)

| Eval Case | Status | Issues |
|---|---|---|
| eval-01-basic-crud-spec | PASS | — |
| eval-02-auth-spec | PASS | — |
| eval-03-api-spec | PASS | — |

## Note

This report validates STRUCTURE only (SE-204 Slice 1-2).
REPORT
  }

  # Helper: create a report with FAIL cases
  _make_fail_report() {
    cat > "${TMPDIR}/output/eval-report-20991231.md" <<'REPORT'
# Eval Report — 20991231

> SE-204: Evaluation harness structural validation
> Agent filter: all
> Threshold: 80%

## Summary

| Metric | Value |
|---|---|
| Total eval cases | 3 |
| Passed | 1 |
| Failed | 2 |
| Score | 33% |
| Threshold | 80% |
| Result | FAIL |

## Results by Agent

### sdd-spec-writer

Score: 1/3 (33%)

| Eval Case | Status | Issues |
|---|---|---|
| eval-01-basic-crud-spec | PASS | — |
| eval-02-auth-spec | FAIL | input.md has 10 words (need >= 50) |
| eval-03-api-spec | FAIL | criteria.md has 2 criteria (need >= 5) |

## Note

This report validates STRUCTURE only.
REPORT
  }

  export -f _make_pass_report _make_fail_report 2>/dev/null || true
}

teardown() {
  [[ -n "${TMPDIR:-}" && "$TMPDIR" == /tmp/* ]] && rm -rf "$TMPDIR"
}

# ---------------------------------------------------------------------------
# Test 1: script exists and is executable
# ---------------------------------------------------------------------------
@test "T01: script exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

# ---------------------------------------------------------------------------
# Test 2: set -uo pipefail present
# ---------------------------------------------------------------------------
@test "T02: set -uo pipefail is present in script" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

# ---------------------------------------------------------------------------
# Test 3: SE-215 referenced in script
# ---------------------------------------------------------------------------
@test "T03: SE-215 is referenced in the script" {
  grep -q 'SE-215' "$SCRIPT"
}

# ---------------------------------------------------------------------------
# Test 4: --dry-run does not create files
# ---------------------------------------------------------------------------
@test "T04: --dry-run does not create output files" {
  # Create a failing report so there would normally be output
  cat > "${TMPDIR}/output/eval-report-20991231.md" <<'REPORT'
# Eval Report — 20991231
> Threshold: 80%

## Results by Agent

### sdd-spec-writer

| Eval Case | Status | Issues |
|---|---|---|
| eval-02-auth-spec | FAIL | input.md has 10 words |
REPORT

  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  # No proposals file should be created
  local proposals_count
  proposals_count=$(ls "${TMPDIR}/output/eval-improvement-proposals-"*.md 2>/dev/null | wc -l)
  [ "$proposals_count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 5: --threshold flag is configurable
# ---------------------------------------------------------------------------
@test "T05: --threshold flag changes threshold value" {
  cat > "${TMPDIR}/output/eval-report-20991231.md" <<'REPORT'
# Eval Report — 20991231
> Threshold: 80%

## Results by Agent

### sdd-spec-writer

| Eval Case | Status | Issues |
|---|---|---|
| eval-02-auth-spec | FAIL | input.md has 10 words |
REPORT

  run bash "$SCRIPT" --dry-run --threshold 90
  [ "$status" -eq 0 ]
  [[ "$output" == *"threshold: 90"* ]]
}

# ---------------------------------------------------------------------------
# Test 6: output contains proposal sections for FAIL cases
# ---------------------------------------------------------------------------
@test "T06: output contains Proposal sections for FAIL eval cases" {
  cat > "${TMPDIR}/output/eval-report-20991231.md" <<'REPORT'
# Eval Report — 20991231
> Threshold: 80%

## Results by Agent

### sdd-spec-writer

| Eval Case | Status | Issues |
|---|---|---|
| eval-02-auth-spec | FAIL | input.md has 10 words |
| eval-03-api-spec | FAIL | criteria.md has 2 criteria |
REPORT

  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"## Proposal: improve sdd-spec-writer/eval-02-auth-spec"* ]]
  [[ "$output" == *"## Proposal: improve sdd-spec-writer/eval-03-api-spec"* ]]
}

# ---------------------------------------------------------------------------
# Test 7: run-agent-evals.sh mentions SAVIA_EVAL_AUTO_SUGGEST
# ---------------------------------------------------------------------------
@test "T07: run-agent-evals.sh mentions SAVIA_EVAL_AUTO_SUGGEST" {
  local run_evals
  run_evals="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/run-agent-evals.sh"
  grep -q 'SAVIA_EVAL_AUTO_SUGGEST' "$run_evals"
}

# ---------------------------------------------------------------------------
# Test 8: SAVIA_EVAL_AUTO_SUGGEST=false (default) does not invoke suggest
# ---------------------------------------------------------------------------
@test "T08: SAVIA_EVAL_AUTO_SUGGEST=false (default) — suggest not invoked" {
  # run-agent-evals.sh default should not call eval-improvement-suggest.sh
  local run_evals
  run_evals="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/run-agent-evals.sh"
  # Check the guard: default is "false"
  grep -q 'SAVIA_EVAL_AUTO_SUGGEST:-false' "$run_evals"
}

# ---------------------------------------------------------------------------
# Test 9: exit 0 always (even with failing eval cases)
# ---------------------------------------------------------------------------
@test "T09: script exits 0 always — even with FAIL cases" {
  cat > "${TMPDIR}/output/eval-report-20991231.md" <<'REPORT'
# Eval Report — 20991231
> Threshold: 80%

## Results by Agent

### court-orchestrator

| Eval Case | Status | Issues |
|---|---|---|
| eval-01-review | FAIL | input.md missing |
REPORT

  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 10: edge — no eval reports in output dir → exits gracefully (0)
# ---------------------------------------------------------------------------
@test "T10: no eval reports in output dir exits gracefully with code 0" {
  # Empty output dir (setup already creates it empty of reports)
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 11: edge — empty report → no proposals, exit 0
# ---------------------------------------------------------------------------
@test "T11: empty report file produces no proposals and exits 0" {
  touch "${TMPDIR}/output/eval-report-20991231.md"
  run bash "$SCRIPT" --report "${TMPDIR}/output/eval-report-20991231.md" --dry-run
  [ "$status" -eq 0 ]
  # No proposal sections in output
  [[ "$output" != *"## Proposal:"* ]]
}

# ---------------------------------------------------------------------------
# Test 12: edge — nonexistent --report file → exits gracefully (0)
# ---------------------------------------------------------------------------
@test "T12: nonexistent --report file exits gracefully with code 0" {
  run bash "$SCRIPT" --report "${TMPDIR}/nonexistent-report.md"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Test 13: proposal references the specific agent and eval case
# ---------------------------------------------------------------------------
@test "T13: proposal body references agent name and eval case" {
  cat > "${TMPDIR}/output/eval-report-20991231.md" <<'REPORT'
# Eval Report — 20991231
> Threshold: 80%

## Results by Agent

### business-analyst

| Eval Case | Status | Issues |
|---|---|---|
| eval-01-pbi-decomp | FAIL | criteria.md has 3 criteria (need >= 5) |
REPORT

  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"**Agent**: business-analyst"* ]]
  [[ "$output" == *"**Eval case**: eval-01-pbi-decomp"* ]]
  [[ "$output" == *".opencode/agents/business-analyst.md"* ]]
}

# ---------------------------------------------------------------------------
# Test 14: proposal includes the run action command
# ---------------------------------------------------------------------------
@test "T14: proposal includes run action with --agent flag" {
  cat > "${TMPDIR}/output/eval-report-20991231.md" <<'REPORT'
# Eval Report — 20991231
> Threshold: 80%

## Results by Agent

### sdd-spec-writer

| Eval Case | Status | Issues |
|---|---|---|
| eval-02-auth-spec | FAIL | input.md has 10 words |
REPORT

  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"run-agent-evals.sh --agent sdd-spec-writer"* ]]
}

# ---------------------------------------------------------------------------
# Test 15: score auditor — bash -n syntax check passes
# ---------------------------------------------------------------------------
@test "T15: bash -n syntax check passes (score auditor >= 80)" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}
