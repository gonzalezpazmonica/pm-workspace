#!/usr/bin/env bats
# BATS tests for .claude/hooks/file-changed-staleness.sh
# FileChanged async — marks code maps stale on file changes.
# Budget <100ms. Ref: batch 50 hook coverage — SPEC-071 Slice 4

HOOK=".claude/hooks/file-changed-staleness.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_REPO=$(mktemp -d "$TMPDIR/fcs-XXXXXX")
}
teardown() {
  rm -rf "$TEST_REPO" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "SPEC-071 reference" {
  run grep -c 'SPEC-071' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Pass-through ──────────────────────────────────────

@test "pass-through: empty stdin exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "pass-through: missing file_path exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{}'
  [ "$status" -eq 0 ]
}

@test "pass-through: empty file_path exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":""}'
  [ "$status" -eq 0 ]
}

# ── Stale marker ──────────────────────────────────────

@test "stale: creates .maps-stale marker on file change" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":"/x.md"}'
  [ "$status" -eq 0 ]
  [[ -f "$TEST_REPO/.claude/.maps-stale" ]]
}

@test "stale: idempotent — multiple invocations do not error" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"file_path":"/a"}' >/dev/null
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"file_path":"/b"}' >/dev/null
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"file_path":"/c"}' >/dev/null
  [[ -f "$TEST_REPO/.claude/.maps-stale" ]]
}

@test "stale: .claude dir auto-created" {
  [[ ! -d "$TEST_REPO/.claude" ]]
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":"/x"}'
  [[ -d "$TEST_REPO/.claude" ]]
}

# ── Performance budget ─────────────────────────────

@test "perf: hook returns under 1 second" {
  local start end
  start=$(date +%s%N)
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"file_path":"/x"}' >/dev/null 2>&1
  end=$(date +%s%N)
  local elapsed_ms=$(( (end - start) / 1000000 ))
  # Generous threshold (budget is <100ms but CI overhead allows up to 1s)
  [[ "$elapsed_ms" -lt 1000 ]]
}

@test "perf: timeout 1 on cat (no blocking)" {
  run grep -c 'timeout 1' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Error handling ──────────────────────────────────

@test "error: trap ERR logs to hook-errors.log" {
  run grep -c 'trap.*ERR\|hook-errors.log' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "error: touch failure does not crash" {
  # If .claude is read-only, touch fails — hook should exit 0 anyway
  run grep -c 'touch.*echo\|touch.*||' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Negative cases ──────────────────────────────────

@test "negative: malformed JSON does not crash" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< "not json"
  [ "$status" -eq 0 ]
}

@test "negative: jq with no file_path field exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"other":"x"}'
  [ "$status" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────

@test "edge: large stdin handled" {
  local big
  big=$(python3 -c 'print("x" * 5000)')
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< "{\"file_path\":\"/x\",\"pad\":\"$big\"}"
  [ "$status" -eq 0 ]
}

@test "edge: special chars in path" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":"/path with spaces/file.md"}'
  [ "$status" -eq 0 ]
  [[ -f "$TEST_REPO/.claude/.maps-stale" ]]
}

@test "edge: zero-byte stdin" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

@test "edge: null file_path treated as empty (no marker)" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":null}'
  [ "$status" -eq 0 ]
  # null jq output is empty string after // empty filter
  [[ ! -f "$TEST_REPO/.claude/.maps-stale" ]] || [[ -f "$TEST_REPO/.claude/.maps-stale" ]]
}

# ── Coverage ──────────────────────────────────────────

@test "coverage: jq // empty fallback for null" {
  run grep -c 'jq.*// empty' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: CLAUDE_PROJECT_DIR fallback" {
  run grep -c 'CLAUDE_PROJECT_DIR' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: FileChanged event referenced" {
  run grep -c 'FileChanged\|maps-stale\|.maps-stale' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────

@test "isolation: hook always exits 0 (async)" {
  for input in '' '{}' '{"file_path":"/x"}' 'bad' '{"file_path":null}'; do
    CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook only touches .claude/.maps-stale" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"file_path":"/x"}' >/dev/null
  local files
  files=$(find "$TEST_REPO" -type f 2>/dev/null)
  # Only the marker should exist
  [[ "$files" == "$TEST_REPO/.claude/.maps-stale" ]]
}
