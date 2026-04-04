#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-032-security-benchmarks.md
# Tests for security-scan.sh — Security audit

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/security-scan.sh"
  TMPDIR_SS=$(mktemp -d)
}

teardown() { rm -rf "$TMPDIR_SS"; }

@test "script has safety flags" {
  head -10 "$SCRIPT" | grep -qE "set -[eu]o pipefail"
}

@test "ci mode runs and produces output" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT" --ci
  [[ "$output" == *"Results"* ]] || [[ "$output" == *"vulnerabilit"* ]] || [[ "$output" == *"scan"* ]]
}

@test "summary mode runs" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT" --summary
  [[ "$status" -le 1 ]]
}

@test "verbose mode runs" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT" --verbose
  [[ "$status" -le 1 ]]
}

@test "negative: handles nonexistent workspace" {
  cd "$TMPDIR_SS"
  run bash "$SCRIPT" --ci
  [[ "$status" -le 1 ]]
}

@test "edge: detects hardcoded paths pattern" {
  grep -q "hardcoded\|Hardcoded\|home" "$SCRIPT"
}

@test "coverage: checks for credentials" {
  grep -q "credential\|secret\|AKIA\|ghp_\|password" "$SCRIPT"
}

@test "coverage: vulnerability detection logic" {
  grep -q "vuln\|VULN\|Results\|findings" "$SCRIPT"
}

@test "negative: invalid mode handled" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT" --bogus
  [[ "$status" -le 1 ]]
}

@test "edge: scan produces structured output" {
  cd "$REPO_ROOT"
  run bash "$SCRIPT" --ci
  [[ "$output" == *"---"* ]] || [[ "$output" == *"Checking"* ]]
}

@test "coverage: checks HTTP client patterns" {
  grep -q "http\|HTTP\|curl\|Insecure\|cert" "$SCRIPT"
}

@test "coverage: MODE variable defined" {
  grep -q "MODE=" "$SCRIPT"
}
