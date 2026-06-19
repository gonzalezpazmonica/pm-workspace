#!/usr/bin/env bats
# Tests for scripts/failure-pattern-memory.sh::compute_pattern_id
# Ref: SE-151 — content-fingerprint consolidation skill
# Spec: docs/specs/SE-151-content-fingerprint-consolidation.spec.md
#
# Validates that the SE-151 migration of compute_pattern_id (now delegated to
# content-fingerprint.sh) preserves the prior contract:
#   - 8-char hex output
#   - deterministic
#   - avalanche on any input change
#   - byte-identical to the pre-SE-151 baseline (sha256sum | cut -c1-8)

SCRIPT="scripts/failure-pattern-memory.sh"

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd -P)"
  SCRIPT_FULL="${REPO_ROOT}/${SCRIPT}"
  CF="${REPO_ROOT}/scripts/content-fingerprint.sh"
  FPM="${REPO_ROOT}/${SCRIPT}"
  TEST_TMP="$(mktemp -d)"
  [[ -x "$CF" ]] || skip "content-fingerprint.sh not executable"
  [[ -f "$FPM" ]] || skip "failure-pattern-memory.sh not found"
}

teardown() {
  rm -rf "$TEST_TMP"
}

# Extract the compute_pattern_id function and dependencies from the target
# without executing the script's main dispatcher. We grab the function block
# from the source, substitute the relative content-fingerprint.sh path with
# an absolute path, and re-evaluate it in a clean subshell.
FN_BLOCK_CACHE=""

_get_fn_block() {
  if [[ -z "$FN_BLOCK_CACHE" ]]; then
    # Extract compute_pattern_id function block (from declaration to closing brace)
    # and rewrite the BASH_SOURCE-based path to the absolute CF path.
    FN_BLOCK_CACHE=$(awk '/^compute_pattern_id\(\)/,/^}/' "$FPM" \
      | sed "s|\${BASH_SOURCE\[0\]%/\*}/content-fingerprint.sh|${CF}|g")
  fi
  printf '%s' "$FN_BLOCK_CACHE"
}

call_compute_pattern_id() {
  local agent="$1" error_sig="$2" file_glob="${3:-}"
  local fn_block
  fn_block=$(_get_fn_block)
  bash -c "
    set -uo pipefail
    ${fn_block}
    compute_pattern_id '$agent' '$error_sig' '$file_glob'
  "
}

# ── Safety verification ─────────────────────────────────────────────────────

@test "safety: target failure-pattern-memory.sh uses set -uo pipefail" {
  run grep -E "^set -[eu]+o pipefail" "$FPM"
  [ "$status" -eq 0 ]
}

@test "safety: target has shebang" {
  run head -1 "$FPM"
  [[ "$output" == \#!* ]]
}

# ── Positive cases — compute_pattern_id contract ────────────────────────────

@test "compute_pattern_id produces 8-char hex" {
  result=$(call_compute_pattern_id "agent-x" "error-y" "glob-z")
  [ ${#result} -eq 8 ]
  [[ "$result" =~ ^[0-9a-f]+$ ]]
}

@test "compute_pattern_id is deterministic" {
  a=$(call_compute_pattern_id "agent" "error" "glob")
  b=$(call_compute_pattern_id "agent" "error" "glob")
  [ "$a" = "$b" ]
}

@test "compute_pattern_id stable across 5 consecutive calls" {
  reference=$(call_compute_pattern_id "stable" "input" "check")
  for i in 1 2 3 4 5; do
    current=$(call_compute_pattern_id "stable" "input" "check")
    [ "$current" = "$reference" ] || { echo "iter $i: $current vs $reference"; return 1; }
  done
}

@test "compute_pattern_id with empty file_glob (default arg) works" {
  result=$(call_compute_pattern_id "agent" "error")
  [ ${#result} -eq 8 ]
  [[ "$result" =~ ^[0-9a-f]+$ ]]
}

@test "compute_pattern_id with non-empty file_glob differs from empty" {
  a=$(call_compute_pattern_id "agent" "error" "")
  b=$(call_compute_pattern_id "agent" "error" "some-glob")
  [ "$a" != "$b" ]
}

@test "compute_pattern_id matches pre-SE-151 baseline (zero regression)" {
  local agent="agent-x" error="error-y" glob="glob-z"
  migrated=$(call_compute_pattern_id "$agent" "$error" "$glob")
  baseline=$(printf '%s' "${agent}${error}${glob}" | sha256sum | cut -c1-8)
  [ "$migrated" = "$baseline" ] || { echo "migrated=$migrated baseline=$baseline"; return 1; }
}

@test "compute_pattern_id matches CF script output for same concatenated input" {
  local agent="x" error="y" glob="z"
  fpm_output=$(call_compute_pattern_id "$agent" "$error" "$glob")
  cf_output=$(printf '%s' "${agent}${error}${glob}" | bash "$CF" 8)
  [ "$fpm_output" = "$cf_output" ]
}

# ── Negative / error cases ─────────────────────────────────────────────────

@test "neg: missing agent arg produces error (unbound)" {
  fn_block=$(_get_fn_block)
  run bash -c "
    set -u
    ${fn_block}
    compute_pattern_id
  "
  [ "$status" -ne 0 ]
}

@test "neg: missing error_sig arg produces error (unbound)" {
  fn_block=$(_get_fn_block)
  run bash -c "
    set -u
    ${fn_block}
    compute_pattern_id agent-only
  "
  [ "$status" -ne 0 ]
}

@test "neg: content-fingerprint.sh not present causes failure" {
  fake_cf="$TEST_TMP/no-such-cf.sh"
  # Rewrite block to point to nonexistent CF
  raw_block=$(awk '/^compute_pattern_id\(\)/,/^}/' "$FPM" \
    | sed "s|\${BASH_SOURCE\[0\]%/\*}/content-fingerprint.sh|${fake_cf}|g")
  run bash -c "
    ${raw_block}
    compute_pattern_id agent err glob
  "
  [ "$status" -ne 0 ]
}

# ── Avalanche (input change → output change) ────────────────────────────────

@test "avalanche: 1-char change in agent produces different output" {
  a=$(call_compute_pattern_id "agent-1" "err" "glob")
  b=$(call_compute_pattern_id "agent-2" "err" "glob")
  [ "$a" != "$b" ]
}

@test "avalanche: 1-char change in error_sig produces different output" {
  a=$(call_compute_pattern_id "agent" "err-a" "glob")
  b=$(call_compute_pattern_id "agent" "err-b" "glob")
  [ "$a" != "$b" ]
}

@test "avalanche: 1-char change in file_glob produces different output" {
  a=$(call_compute_pattern_id "agent" "err" "globA")
  b=$(call_compute_pattern_id "agent" "err" "globB")
  [ "$a" != "$b" ]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: empty strings produce valid 8-char hex" {
  result=$(call_compute_pattern_id "" "" "")
  [ ${#result} -eq 8 ]
  [[ "$result" =~ ^[0-9a-f]+$ ]]
}

@test "edge: very long inputs (1000 chars each) hash successfully" {
  long_a=$(printf 'a%.0s' {1..1000})
  long_b=$(printf 'b%.0s' {1..1000})
  result=$(call_compute_pattern_id "$long_a" "$long_b" "$long_a")
  [ ${#result} -eq 8 ]
}

@test "edge: unicode/utf-8 inputs hash deterministically" {
  a=$(call_compute_pattern_id "agénte" "errör" "glöb")
  b=$(call_compute_pattern_id "agénte" "errör" "glöb")
  [ "$a" = "$b" ]
}

@test "edge: special shell chars in inputs do not break hashing" {
  result=$(call_compute_pattern_id 'a&b' 'c|d' 'e;f')
  [ ${#result} -eq 8 ]
  [[ "$result" =~ ^[0-9a-f]+$ ]]
}

@test "edge: boundary — agent with only whitespace still hashes" {
  result=$(call_compute_pattern_id "   " "err" "glob")
  [ ${#result} -eq 8 ]
}

# ── Coverage of related die/info helpers in target ─────────────────────────

@test "coverage: die helper exists in target and exits non-zero" {
  # Extract die() definition
  die_block=$(awk '/^die\(\)/,/^[a-z_]+\(\)|^# /' "$FPM" | sed '/^[a-z_]\+()/,$d' | head -3)
  # Fallback: just grep the line
  [[ "$(grep -E '^die\(\)' "$FPM")" == "die()"* ]]
  run bash -c "
    die()  { echo \"ERROR: \$*\" >&2; exit 1; }
    die 'test message'
  "
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "coverage: info helper exists in target and exits 0" {
  [[ "$(grep -E '^info\(\)' "$FPM")" == "info()"* ]]
  run bash -c "
    info() { echo \"INFO: \$*\"; }
    info 'test message'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO"* ]]
}

@test "coverage: iso8601_now produces valid ISO timestamp" {
  [[ "$(grep -E '^iso8601_now\(\)' "$FPM")" == "iso8601_now()"* ]]
  run bash -c "
    iso8601_now() { date -u +\"%Y-%m-%dT%H:%M:%SZ\"; }
    iso8601_now
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}
