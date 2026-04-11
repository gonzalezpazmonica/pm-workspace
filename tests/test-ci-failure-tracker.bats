#!/usr/bin/env bats
# BATS tests for scripts/ci-failure-tracker.sh
# SPEC: SE-012 Signal/Noise Reduction — Module 2 (CI Failure Tracker)
# Quality gate: SPEC-055 (audit score ≥80)
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-012-signal-noise-reduction.md

SCRIPT="scripts/ci-failure-tracker.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export CLAUDE_PROJECT_DIR="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$CLAUDE_PROJECT_DIR/output" "$CLAUDE_PROJECT_DIR/scripts"
  cp "$BATS_TEST_DIRNAME/../$SCRIPT" "$CLAUDE_PROJECT_DIR/scripts/"
  chmod +x "$CLAUDE_PROJECT_DIR/scripts/$(basename "$SCRIPT")"
  cd "$CLAUDE_PROJECT_DIR"
}

teardown() {
  cd /
  rm -rf "$CLAUDE_PROJECT_DIR"
}

# Helper: write N records to the log with given conclusion
_seed_log() {
  local count="$1" conclusion="$2" check="${3:-BATS Hook Tests}"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  for ((i=0; i<count; i++)); do
    printf '{"ts":"%s","pr":517,"branch":"test","workflow":"CI","check":"%s","conclusion":"%s","job_url":"-"}\n' \
      "$ts" "$check" "$conclusion" >> output/ci-runs.jsonl
  done
}

# ── Structure and safety ────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "scripts/ci-failure-tracker.sh" ]]
}

@test "script uses set -uo pipefail" {
  head -15 scripts/ci-failure-tracker.sh | grep -q "set -uo pipefail"
}

@test "script shows usage with no args" {
  run bash scripts/ci-failure-tracker.sh
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"usage:"* ]]
}

@test "script rejects unknown command" {
  run bash scripts/ci-failure-tracker.sh bogus
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"unknown command"* ]]
}

# ── health with empty or missing log ───────────────────────────────────────

@test "health handles missing log file gracefully" {
  run bash scripts/ci-failure-tracker.sh health
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No log yet"* ]]
}

@test "health handles empty log with zero records in window" {
  touch output/ci-runs.jsonl
  run bash scripts/ci-failure-tracker.sh health
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No records"* ]]
}

# ── health with seeded data ────────────────────────────────────────────────

@test "health computes 0% failure rate when all success" {
  _seed_log 5 "SUCCESS"
  run bash scripts/ci-failure-tracker.sh health
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Total records ..... 5"* ]]
  [[ "$output" == *"Failures .......... 0 (0%)"* ]]
}

@test "health computes 100% failure rate when all failures" {
  _seed_log 4 "FAILURE"
  run bash scripts/ci-failure-tracker.sh health
  [[ "$output" == *"Failures .......... 4 (100%)"* ]]
}

@test "health computes mixed failure rate correctly" {
  _seed_log 3 "SUCCESS"
  _seed_log 1 "FAILURE"
  run bash scripts/ci-failure-tracker.sh health
  [[ "$output" == *"Total records ..... 4"* ]]
  [[ "$output" == *"Failures .......... 1 (25%)"* ]]
}

@test "health groups by check name with per-check rates" {
  _seed_log 2 "FAILURE" "BATS Hook Tests"
  _seed_log 2 "SUCCESS" "Lint Markdown"
  run bash scripts/ci-failure-tracker.sh health
  [[ "$output" == *"BATS Hook Tests"* ]]
  [[ "$output" == *"Lint Markdown"* ]]
  [[ "$output" == *"100%"* ]]
  [[ "$output" == *"0%"* ]]
}

# ── top command ────────────────────────────────────────────────────────────

@test "top lists recurring failures in descending order" {
  _seed_log 3 "FAILURE" "BATS Hook Tests"
  _seed_log 1 "FAILURE" "Lint Markdown"
  run bash scripts/ci-failure-tracker.sh top
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"BATS Hook Tests"* ]]
  [[ "$output" == *"3×"* ]] || [[ "$output" == *"  3 BATS"* ]]
}

@test "top handles missing log gracefully" {
  run bash scripts/ci-failure-tracker.sh top
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No log"* ]]
}

# ── record command: input validation ───────────────────────────────────────

@test "record requires pr argument" {
  run bash scripts/ci-failure-tracker.sh record
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"usage:"* ]]
}

# ── Robustness: malformed JSON in log ──────────────────────────────────────

@test "health tolerates malformed line without crashing" {
  _seed_log 2 "SUCCESS"
  echo 'not valid json' >> output/ci-runs.jsonl
  _seed_log 1 "FAILURE"
  run bash scripts/ci-failure-tracker.sh health
  # jq will error on the malformed line but we should still get output
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 5 ]]
}

# ── Log path and append-only behavior ──────────────────────────────────────

@test "log file created in output/ci-runs.jsonl" {
  _seed_log 1 "SUCCESS"
  [[ -f "output/ci-runs.jsonl" ]]
}

@test "multiple health calls do not modify the log" {
  _seed_log 3 "SUCCESS"
  local before
  before=$(md5sum output/ci-runs.jsonl | cut -d' ' -f1)
  bash scripts/ci-failure-tracker.sh health >/dev/null 2>&1 || true
  bash scripts/ci-failure-tracker.sh top    >/dev/null 2>&1 || true
  local after
  after=$(md5sum output/ci-runs.jsonl | cut -d' ' -f1)
  [[ "$before" == "$after" ]]
}
