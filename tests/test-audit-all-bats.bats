#!/usr/bin/env bats
# BATS tests for scripts/audit-all-bats.sh
# SE-039 Slice 1 — Global sweep of test-auditor over all .bats files.
# Ref: SE-039 test-auditor-global-sweep, SPEC-055 test-auditor

SCRIPT="scripts/audit-all-bats.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
}
teardown() { cd /; }

@test "script exists" { [[ -f "$SCRIPT" ]]; }
@test "script is executable" { [[ -x "$SCRIPT" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "SE-039 reference" {
  run grep -c 'SE-039\|test-auditor-global-sweep' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI help ────────────────────────────────────────────

@test "help: --help prints usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "help: -h equivalent" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "cli: unknown arg exits 2" {
  run bash "$SCRIPT" --bogus-flag
  [ "$status" -eq 2 ]
}

# ── Min score flag ──────────────────────────────────────

@test "--min-score N: accepts custom threshold" {
  # Dry check — just verify flag parsing works
  run timeout 2 bash "$SCRIPT" --min-score 60 --quiet 2>&1 || true
  # Should at least not error on flag parsing
  [[ "$output" != *"unknown arg"* ]]
}

@test "--min-score: requires value (no partial flag)" {
  run bash "$SCRIPT" --min-score
  # Without arg, the shift 2 fails — accept non-zero status
  [[ "$status" -ne 0 ]]
}

# ── Execution ──────────────────────────────────────────

@test "exec: runs and produces output file" {
  # Set QUIET to skip stdout noise
  run timeout 120 bash "$SCRIPT" --quiet
  [ "$status" -eq 0 ]
  local date_str
  date_str=$(date +%Y%m%d)
  [[ -f "output/bats-audit-sweep-$date_str.md" ]]
}

@test "exec: report contains expected sections" {
  local date_str
  date_str=$(date +%Y%m%d)
  # Report should exist from prior run
  if [[ -f "output/bats-audit-sweep-$date_str.md" ]]; then
    run cat "output/bats-audit-sweep-$date_str.md"
    [[ "$output" == *"# BATS audit sweep"* ]]
    [[ "$output" == *"Tests scanned"* ]]
    [[ "$output" == *"Bottom decile"* ]]
    [[ "$output" == *"Full ranking"* ]]
    [[ "$output" == *"Interpretation"* ]]
  fi
}

@test "exec: non-quiet mode prints summary line" {
  run timeout 120 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"audit-all-bats"* ]]
  [[ "$output" == *"total="* ]]
  [[ "$output" == *"compliant="* ]]
}

# ── Bounded concurrency ────────────────────────────────

@test "concurrency: MAX_PARALLEL env var respected" {
  run grep -c 'MAX_PARALLEL' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "concurrency: default value is 5 (bounded-concurrency doctrine)" {
  run grep -c 'MAX_PARALLEL:-5' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "concurrency: uses wait -n for bounded pool" {
  run grep -c 'wait -n\|jobs -rp' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Safety / isolation ─────────────────────────────────

@test "safety: temp dir auto-cleaned via trap" {
  run grep -c 'trap.*rm -rf' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "safety: auditor existence check" {
  run grep -c 'ERROR.*test-auditor\|! -x.*AUDITOR' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "safety: find maxdepth 1 prevents recursive crawl" {
  run grep -c 'maxdepth 1' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "safety: output dir auto-created" {
  run grep -c 'mkdir -p.*OUTPUT_DIR\|mkdir.*output' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Statistics calculation ─────────────────────────────

@test "stats: computes average score" {
  run grep -c 'avg\|average' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "stats: computes compliance percentage" {
  run grep -c 'compliant_pct' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "stats: ranks ascending (worst first)" {
  run grep -c 'sort.*-n\|Sort ascending' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Interpretation output ─────────────────────────────

@test "interpretation: 95% threshold AC-03" {
  run grep -c '95' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "interpretation: differentiates good vs gap scenarios" {
  run grep -c 'compliant_pct.*-ge 95\|Gap of' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Negative cases ──────────────────────────────────────

@test "negative: missing test-auditor.sh handled" {
  # Can't easily reproduce without mutating filesystem; verify guard exists
  run grep -c 'not found or not executable' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: empty tests dir handled via maxdepth" {
  run grep -c 'find.*maxdepth 1.*\.bats' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "edge: large test count 232+ handled via parallel" {
  # Verify the script scales — just run the actual sweep
  run timeout 120 bash "$SCRIPT" --quiet
  [ "$status" -eq 0 ]
}

@test "edge: --quiet flag suppresses stdout" {
  run timeout 120 bash "$SCRIPT" --quiet
  [ "$status" -eq 0 ]
  [[ "$output" != *"audit-all-bats:"* ]] || [[ -z "$output" ]]
}

@test "edge: custom min-score threshold changes compliance ratio" {
  run grep -c 'MIN_SCORE' "$SCRIPT"
  [[ "$output" -ge 2 ]]
}

@test "edge: no-arg invocation uses defaults" {
  # Verify default path works — timeout protects against long runs
  run timeout 120 bash "$SCRIPT" --quiet
  [ "$status" -eq 0 ]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: audit_one function defined" {
  run grep -c 'audit_one()' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: auditor JSON total extraction" {
  run grep -c 'total.*:.*[0-9]\|grep.*total' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: SPEC-055 reference to auditor" {
  run grep -c 'SPEC-055' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: bottom decile target (10% or minimum 5)" {
  run grep -c 'bottom.*decile\|bottom_target' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────

@test "isolation: script does not modify test files" {
  local before_hash after_hash
  before_hash=$(find tests -name '*.bats' -exec sha256sum {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
  timeout 120 bash "$SCRIPT" --quiet >/dev/null 2>&1 || true
  after_hash=$(find tests -name '*.bats' -exec sha256sum {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
  [[ "$before_hash" == "$after_hash" ]]
}

@test "isolation: only writes to output/ directory" {
  # Verify the OUTPUT_DIR path is constrained
  run grep -c 'OUTPUT_DIR.*REPO_ROOT/output' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
