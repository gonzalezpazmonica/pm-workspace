#!/usr/bin/env bats
# BATS tests for scripts/compress-skip-frozen.sh (SE-029 Slice 3).
# Validates frozen-core advisory: SKIP/COMPRESS verdict per class, JSON output,
# strict mode exit codes, CLI surface, negatives, edges.
#
# Ref: SE-029 §4 (SE-029-F), ROADMAP §Tier 4.1
# Dep: scripts/context-task-classify.sh (Slice 2)
# Safety: script under test has `set -uo pipefail`, read-only.

SCRIPT="scripts/compress-skip-frozen.sh"
CLASSIFIER="scripts/context-task-classify.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "classifier dependency exists and is executable" {
  [[ -x "$CLASSIFIER" ]]
}

@test "script uses set -uo pipefail" {
  run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

@test "script passes bash -n syntax check" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script references SE-029 and Slice 3" {
  run grep -c 'SE-029' "$SCRIPT"
  [[ "$output" -ge 1 ]]
  run grep -c 'Slice 3\|SE-029-F' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}

# ── CLI surface ─────────────────────────────────────────────────────────────

@test "script accepts --help and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP"* ]]
  [[ "$output" == *"COMPRESS"* ]]
}

@test "script rejects unknown arg" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}

@test "script rejects no-args invocation" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "script rejects nonexistent input file" {
  run bash "$SCRIPT" --input /does/not/exist.txt
  [ "$status" -eq 2 ]
}

# ── Verdict — frozen classes return SKIP ────────────────────────────────────

@test "decision class returns SKIP verdict" {
  run bash -c 'echo "APPROVED — merge PR #624" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP"* ]]
  [[ "$output" == *"decision"* ]]
}

@test "spec class returns SKIP verdict" {
  run bash -c 'echo "SPEC-120 AC-01 implemented" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP"* ]]
  [[ "$output" == *"spec"* ]]
}

# ── Verdict — non-frozen classes return COMPRESS ────────────────────────────

@test "chitchat class returns COMPRESS verdict" {
  run bash -c 'echo "thanks" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPRESS"* ]]
  [[ "$output" != *"COMPRESS_LIMITED"* ]]
  [[ "$output" == *"chitchat"* ]]
}

@test "review class returns COMPRESS verdict" {
  run bash -c 'echo "G6 BATS tests PASS: 227/228 suites" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPRESS"* ]]
  [[ "$output" == *"review"* ]]
}

# ── Verdict — code class returns COMPRESS_LIMITED (partial frozen) ──────────

@test "code class returns COMPRESS_LIMITED verdict (partial frozen)" {
  local tmp="$BATS_TEST_TMPDIR/code.txt"
  printf '%s\n' '```python' 'def foo():' '    pass' '```' > "$tmp"
  run bash "$SCRIPT" --input "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPRESS_LIMITED"* ]]
  [[ "$output" == *"code"* ]]
}

# ── JSON output ─────────────────────────────────────────────────────────────

@test "json output is valid JSON with expected fields" {
  run bash -c 'echo "APPROVED" | bash '"$SCRIPT"' --stdin --json'
  [ "$status" -eq 0 ]
  run bash -c 'echo "APPROVED" | bash '"$SCRIPT"' --stdin --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert \"verdict\" in d; assert \"class\" in d; assert \"frozen\" in d; assert \"max_ratio\" in d; assert \"reason\" in d; print(\"ok\")"'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "json SKIP verdict matches frozen decision class" {
  run bash -c 'echo "APPROVED" | bash '"$SCRIPT"' --stdin --json'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"verdict":"SKIP"'* ]]
  [[ "$output" == *'"class":"decision"'* ]]
  [[ "$output" == *'"frozen":"true"'* ]]
}

@test "json COMPRESS verdict for chitchat" {
  run bash -c 'echo "thanks" | bash '"$SCRIPT"' --stdin --json'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"verdict":"COMPRESS"'* ]]
  [[ "$output" == *'"max_ratio":80'* ]]
}

# ── Strict mode ─────────────────────────────────────────────────────────────

@test "strict mode: SKIP verdict exits 1" {
  run bash -c 'echo "APPROVED" | bash '"$SCRIPT"' --stdin --strict'
  [ "$status" -eq 1 ]
  [[ "$output" == *"SKIP"* ]]
}

@test "strict mode: COMPRESS verdict exits 0" {
  run bash -c 'echo "thanks" | bash '"$SCRIPT"' --stdin --strict'
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPRESS"* ]]
}

@test "advisory mode (default): SKIP still exits 0" {
  run bash -c 'echo "APPROVED" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP"* ]]
}

# ── Negative cases ─────────────────────────────────────────────────────────

@test "negative: --stdin requires piped input (empty handled gracefully)" {
  # Empty stdin classifier→chitchat (non-frozen) → COMPRESS
  run bash -c ': | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
}

@test "negative: unknown flag returns exit 2" {
  run bash "$SCRIPT" --no-such-flag
  [ "$status" -eq 2 ]
}

@test "negative: nonexistent input file returns exit 2 with error" {
  run bash "$SCRIPT" --input /tmp/does-not-exist-$RANDOM.txt
  [ "$status" -eq 2 ]
  [[ "$output" == *"not found"* ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: 3 verdict types declared in script" {
  run grep -cE 'SKIP|COMPRESS_LIMITED|COMPRESS' "$SCRIPT"
  [[ "$output" -ge 3 ]]
}

@test "edge: both file input and stdin modes work on same content" {
  local tmp="$BATS_TEST_TMPDIR/same.txt"
  echo "APPROVED — ship" > "$tmp"
  run bash "$SCRIPT" --input "$tmp"
  [ "$status" -eq 0 ]
  local file_out="$output"
  run bash -c 'echo "APPROVED — ship" | bash '"$SCRIPT"' --stdin'
  [ "$status" -eq 0 ]
  [[ "$output" == "$file_out" ]]
}

@test "edge: script degrades gracefully if classifier missing" {
  # Temporarily hide the classifier to verify error path.
  local tmp="$BATS_TEST_TMPDIR/fake-repo"
  mkdir -p "$tmp/scripts"
  cp "$SCRIPT" "$tmp/scripts/compress-skip-frozen.sh"
  # Classifier deliberately NOT copied.
  run env REPO_ROOT="$tmp" bash "$tmp/scripts/compress-skip-frozen.sh" --stdin <<< "test"
  [ "$status" -eq 2 ]
  [[ "$output" == *"classifier not found"* ]]
}

# ── Isolation ──────────────────────────────────────────────────────────────

@test "isolation: script does not modify input file" {
  local tmp="$BATS_TEST_TMPDIR/ro.txt"
  echo "SPEC-120 AC-01" > "$tmp"
  local hash_before
  hash_before=$(md5sum "$tmp" | awk '{print $1}')
  bash "$SCRIPT" --input "$tmp" >/dev/null 2>&1
  local hash_after
  hash_after=$(md5sum "$tmp" | awk '{print $1}')
  [[ "$hash_before" == "$hash_after" ]]
}

@test "isolation: advisory and strict produce same verdict string" {
  run bash -c 'echo "thanks" | bash '"$SCRIPT"' --stdin'
  local v1; v1=$(echo "$output" | head -1)
  run bash -c 'echo "thanks" | bash '"$SCRIPT"' --stdin --strict'
  local v2; v2=$(echo "$output" | head -1)
  [[ "$v1" == "$v2" ]]
}
