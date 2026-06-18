#!/usr/bin/env bats
# Tests for scripts/failure-pattern-memory.sh:compute_pattern_id
# SE-151: validate that SE-151 migration of compute_pattern_id is regression-free.
# Strategy: invoke compute_pattern_id via bash -c that pipes stdin into content-fingerprint.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd -P)"
  CF="${REPO_ROOT}/scripts/content-fingerprint.sh"
  [[ -x "$CF" ]] || skip "content-fingerprint.sh not executable"
}

# Mimic the post-SE-151 implementation of compute_pattern_id
# Reproduces the migrated line: printf | bash content-fingerprint.sh 8
compute_pattern_id_under_test() {
  local agent="$1" error_sig="$2" file_glob="${3:-}"
  printf '%s' "${agent}${error_sig}${file_glob}" | bash "$CF" 8
}

@test "compute_pattern_id produces 8-char hex" {
  result=$(compute_pattern_id_under_test "agent-x" "error-y" "glob-z")
  [ ${#result} -eq 8 ]
  [[ "$result" =~ ^[0-9a-f]+$ ]]
}

@test "compute_pattern_id is deterministic" {
  a=$(compute_pattern_id_under_test "agent" "error" "glob")
  b=$(compute_pattern_id_under_test "agent" "error" "glob")
  [ "$a" = "$b" ]
}

@test "compute_pattern_id avalanche: different inputs produce different output" {
  a=$(compute_pattern_id_under_test "agent" "error" "glob")
  b=$(compute_pattern_id_under_test "agent" "error" "globZ")
  [ "$a" != "$b" ]
}

@test "compute_pattern_id matches pre-SE-151 baseline (zero regression)" {
  local agent="agent-x" error="error-y" glob="glob-z"
  local migrated; migrated=$(compute_pattern_id_under_test "$agent" "$error" "$glob")
  local baseline; baseline=$(printf '%s' "${agent}${error}${glob}" | sha256sum | cut -c1-8)
  [ "$migrated" = "$baseline" ] || { echo "migrated=$migrated baseline=$baseline"; return 1; }
}

@test "compute_pattern_id with empty file_glob (default arg)" {
  result=$(compute_pattern_id_under_test "agent" "error")
  [ ${#result} -eq 8 ]
}

@test "compute_pattern_id avalanche on agent only" {
  a=$(compute_pattern_id_under_test "agent-1" "err" "glob")
  b=$(compute_pattern_id_under_test "agent-2" "err" "glob")
  [ "$a" != "$b" ]
}
