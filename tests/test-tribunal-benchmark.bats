#!/usr/bin/env bats
# tests/test-tribunal-benchmark.bats
# BATS tests for SPEC-106 Phase 3 — tribunal-benchmark.sh.
# Verifies sample dataset generation, deterministic aggregation against
# expected verdicts, compliance-gate override, results file output,
# and metrics computation.
#
# Ref: SPEC-106 Phase 3 (calibration harness)
# Ref: SPEC-055 (test quality gate, score >=80)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  BENCH="$REPO_ROOT/scripts/tribunal-benchmark.sh"
  TRIBUNAL="$REPO_ROOT/scripts/truth-tribunal.sh"
  TMPDIR_TEST=$(mktemp -d)
  DATASET="$TMPDIR_TEST/bench"
  export TRUTH_TRIBUNAL_CACHE="$TMPDIR_TEST/cache"
  mkdir -p "$TRUTH_TRIBUNAL_CACHE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── Script structure ──────────────────────────────────────────────────────

@test "benchmark script exists and is executable" {
  [[ -x "$BENCH" ]]
}

@test "benchmark script uses set -uo pipefail" {
  head -3 "$BENCH" | grep -q "set -uo pipefail"
}

@test "benchmark help prints usage" {
  run bash "$BENCH" help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"tribunal-benchmark.sh"* ]]
  [[ "$output" == *"sample"* ]]
  [[ "$output" == *"run"* ]]
}

@test "unknown subcommand exits 2" {
  run bash "$BENCH" frobnicate
  [[ "$status" -eq 2 ]]
}

# ── Sample generation ─────────────────────────────────────────────────────

@test "sample creates 6 cases" {
  run bash "$BENCH" sample "$DATASET"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"6 sample cases"* ]]
  local count
  count=$(find "$DATASET" -maxdepth 1 -name "case-*" -type d 2>/dev/null | wc -l)
  [[ "$count" -eq 6 ]]
}

@test "each generated case has report.md, expected.yaml, and 7 judges" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  for case_dir in "$DATASET"/case-*; do
    [[ -f "$case_dir/report.md" ]]
    [[ -f "$case_dir/expected.yaml" ]]
    local judge_ct
    judge_ct=$(find "$case_dir/judges" -name "*.yaml" 2>/dev/null | wc -l)
    [[ "$judge_ct" -eq 7 ]]
  done
}

@test "report.md contains report_type frontmatter for profile detection" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  grep -q "report_type:" "$DATASET/case-001/report.md"
  grep -q "report_type: compliance" "$DATASET/case-003/report.md"
  grep -q "report_type: digest" "$DATASET/case-005/report.md"
}

@test "expected.yaml contains verdict and profile fields" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  grep -q "^verdict:" "$DATASET/case-001/expected.yaml"
  grep -q "^profile:" "$DATASET/case-001/expected.yaml"
}

# ── Run: deterministic aggregation ────────────────────────────────────────

@test "run rejects nonexistent dataset" {
  run bash "$BENCH" run "/nonexistent/dataset"
  [[ "$status" -eq 2 ]]
  [[ "$output" == *"ERROR"* ]]
}

@test "run on sample dataset achieves 100% accuracy" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  run bash "$BENCH" run "$DATASET"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Accuracy: 100.0%"* ]]
}

@test "run reports per-case OK/FAIL marks" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  run bash "$BENCH" run "$DATASET"
  [[ "$output" == *"case-001"* ]]
  [[ "$output" == *"case-006"* ]]
  [[ "$output" == *"OK"* ]]
}

@test "run exits non-zero when a case fails" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  # Sabotage case-001 by inverting the expected verdict
  echo "verdict: ITERATE" > "$DATASET/case-001/expected.yaml"
  echo "profile: default" >> "$DATASET/case-001/expected.yaml"
  run bash "$BENCH" run "$DATASET"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"FAIL"* ]]
}

# ── Compliance gate override ──────────────────────────────────────────────

@test "compliance gate override: case-003 (low compliance) verdict ITERATE" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  bash "$BENCH" run "$DATASET" >/tmp/bench-out.$$ 2>&1
  grep -q "case-003" /tmp/bench-out.$$
  # case-003 has 6 judges at 95 + compliance=80 + profile=compliance.
  # Compliance gate forces ITERATE despite high weighted score.
  grep "case-003" /tmp/bench-out.$$ | grep -q "ITERATE"
  grep "case-003" /tmp/bench-out.$$ | grep -q "OK"
  rm -f /tmp/bench-out.$$
}

# ── Results file ─────────────────────────────────────────────────────────

@test "run writes results file when path provided" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  local results="$TMPDIR_TEST/results.jsonl"
  bash "$BENCH" run "$DATASET" "$results" >/dev/null
  [[ -f "$results" ]]
  local lines
  lines=$(wc -l < "$results")
  [[ "$lines" -eq 6 ]]
}

@test "results file contains valid JSON per line" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  local results="$TMPDIR_TEST/results.jsonl"
  bash "$BENCH" run "$DATASET" "$results" >/dev/null
  while IFS= read -r line; do
    echo "$line" | python3 -c 'import sys,json; d=json.loads(sys.stdin.read()); assert "case" in d and "expected" in d and "actual" in d and "match" in d'
  done < "$results"
}

# ── Metrics ──────────────────────────────────────────────────────────────

@test "metrics requires existing results file" {
  run bash "$BENCH" metrics "/nonexistent/results.jsonl"
  [[ "$status" -eq 2 ]]
}

@test "metrics computes accuracy from results file" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  local results="$TMPDIR_TEST/results.jsonl"
  bash "$BENCH" run "$DATASET" "$results" >/dev/null
  run bash "$BENCH" metrics "$results"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Cases: 6"* ]]
  [[ "$output" == *"Accuracy: 100.0%"* ]]
}

# ── Edge cases ───────────────────────────────────────────────────────────

@test "run handles dataset with mixed valid and incomplete cases" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  # Add an incomplete case missing expected.yaml
  mkdir -p "$DATASET/case-bad/judges"
  echo "# Bad" > "$DATASET/case-bad/report.md"
  run bash "$BENCH" run "$DATASET"
  # Should skip the bad case and still process the others
  [[ "$output" == *"SKIP"* ]] || [[ "$output" == *"Cases:"* ]]
}

@test "sample is idempotent: running twice produces identical layout" {
  bash "$BENCH" sample "$DATASET" >/dev/null
  local sig1
  sig1=$(find "$DATASET" -type f -name "*.yaml" | sort | xargs sha256sum | sha256sum)
  bash "$BENCH" sample "$DATASET" >/dev/null
  local sig2
  sig2=$(find "$DATASET" -type f -name "*.yaml" | sort | xargs sha256sum | sha256sum)
  [[ "$sig1" == "$sig2" ]]
}
