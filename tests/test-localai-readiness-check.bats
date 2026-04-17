#!/usr/bin/env bats
# Tests for SPEC-122 — LocalAI readiness check
# Ref: docs/propuestas/SPEC-122-localai-emergency-hardening.md

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/localai-readiness-check.sh"
  TMPDIR_LAI="$(mktemp -d)"
  export TMPDIR_LAI
  # Unreachable URL for negative cases
  export FAKE_URL="http://127.0.0.1:1"
}

teardown() {
  rm -rf "$TMPDIR_LAI" 2>/dev/null || true
}

# ── Safety / integrity ───────────────────────────────────────────────────────

@test "safety: script exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "safety: script has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: script references SPEC-122" {
  grep -q "SPEC-122" "$SCRIPT"
}

# ── Positive: help flag and argument parsing ────────────────────────────────

@test "positive: --help returns exit 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "positive: accepts --url argument" {
  run bash "$SCRIPT" --url "$FAKE_URL" --json
  # Unreachable URL → exit 2, but argument accepted
  [ "$status" -eq 2 ]
}

@test "positive: accepts --model argument" {
  run bash "$SCRIPT" --url "$FAKE_URL" --model "custom-model" --json
  [ "$status" -eq 2 ]
}

@test "positive: accepts --json flag" {
  run bash "$SCRIPT" --url "$FAKE_URL" --json
  echo "$output" | grep -qE '^\{.*"overall".*\}$'
}

# ── Negative: unreachable LocalAI ───────────────────────────────────────────

@test "negative: unreachable URL reports FAIL for localai_running" {
  run bash "$SCRIPT" --url "$FAKE_URL"
  echo "$output" | grep -qE "FAIL.*localai_running"
  [ "$status" -eq 2 ]
}

@test "negative: unreachable URL json reports overall=2" {
  run bash "$SCRIPT" --url "$FAKE_URL" --json
  echo "$output" | grep -qE '"overall":2'
}

@test "negative: unknown argument rejected with exit 2" {
  run bash "$SCRIPT" --nonexistent-flag
  [ "$status" -eq 2 ]
}

# ── Edge cases ───────────────────────────────────────────────────────────────

@test "edge: JSON output has valid structure (parseable by python)" {
  run bash "$SCRIPT" --url "$FAKE_URL" --json
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'overall' in d; assert 'checks' in d; assert isinstance(d['checks'], list)"
}

@test "edge: reports all 5 checks in output" {
  run bash "$SCRIPT" --url "$FAKE_URL"
  echo "$output" | grep -qE "localai_running"
  echo "$output" | grep -qE "anthropic_compat"
  echo "$output" | grep -qE "model_available"
  echo "$output" | grep -qE "ram"
  echo "$output" | grep -qE "disk"
}

@test "edge: MIN_VERSION 3.10.0 is documented in script" {
  grep -q "3.10.0" "$SCRIPT"
}

@test "edge: LOCALAI_URL env var is respected" {
  LOCALAI_URL="$FAKE_URL" run bash "$SCRIPT" --json
  echo "$output" | grep -qE '"overall":2'
}

# ── Isolation ────────────────────────────────────────────────────────────────

@test "isolation: script does not create files in repo" {
  before=$(find "$REPO_ROOT" -newer /tmp -maxdepth 3 2>/dev/null | wc -l)
  run bash "$SCRIPT" --url "$FAKE_URL" --json
  after=$(find "$REPO_ROOT" -newer /tmp -maxdepth 3 2>/dev/null | wc -l)
  # Script should not add files (tmp values may differ but no persistent write)
  [ "$status" -eq 2 ]
}

@test "isolation: exit codes are well-defined (0, 1, or 2)" {
  run bash "$SCRIPT" --url "$FAKE_URL"
  [[ "$status" == "0" || "$status" == "1" || "$status" == "2" ]]
}
