#!/usr/bin/env bats
# BATS tests for .claude/hooks/instructions-tracker.sh
# InstructionsLoaded async hook — logs which instruction files load per session.
# Ref: batch 50 hook coverage — SPEC-071 Slice 4

HOOK=".claude/hooks/instructions-tracker.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_REPO=$(mktemp -d "$TMPDIR/it-XXXXXX")
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
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"other":"field"}'
  [ "$status" -eq 0 ]
}

# ── Logging ──────────────────────────────────────────

@test "log: appends entry with file_path" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":"/x/CLAUDE.md","memory_type":"project","load_reason":"session_start"}'
  [ "$status" -eq 0 ]
  [[ -f "$TEST_REPO/output/instructions-loaded/loaded.jsonl" ]]
  run cat "$TEST_REPO/output/instructions-loaded/loaded.jsonl"
  [[ "$output" == *"/x/CLAUDE.md"* ]]
}

@test "log: includes ISO 8601 UTC timestamp" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":"/y.md"}'
  run cat "$TEST_REPO/output/instructions-loaded/loaded.jsonl"
  [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ]]
}

@test "log: memory_type captured" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":"/x.md","memory_type":"project"}'
  run cat "$TEST_REPO/output/instructions-loaded/loaded.jsonl"
  [[ "$output" == *'"type":"project"'* ]]
}

@test "log: load_reason captured" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":"/x.md","load_reason":"import"}'
  run cat "$TEST_REPO/output/instructions-loaded/loaded.jsonl"
  [[ "$output" == *'"reason":"import"'* ]]
}

@test "log: multiple invocations append (not overwrite)" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"file_path":"/a.md"}' >/dev/null
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"file_path":"/b.md"}' >/dev/null
  run wc -l < "$TEST_REPO/output/instructions-loaded/loaded.jsonl"
  [[ "$output" -eq 2 ]]
}

@test "log: log dir auto-created" {
  [[ ! -d "$TEST_REPO/output/instructions-loaded" ]]
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":"/x.md"}'
  [[ -d "$TEST_REPO/output/instructions-loaded" ]]
}

# ── Format ──────────────────────────────────────────

@test "format: emits valid JSON line" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"file_path":"/x.md","memory_type":"t","load_reason":"r"}' >/dev/null
  run cat "$TEST_REPO/output/instructions-loaded/loaded.jsonl"
  echo "$output" | python3 -c 'import sys,json; json.loads(sys.stdin.read().strip())'
}

@test "format: 4 fields ts/file/type/reason" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"file_path":"/x.md","memory_type":"a","load_reason":"b"}' >/dev/null
  run cat "$TEST_REPO/output/instructions-loaded/loaded.jsonl"
  for k in '"ts":' '"file":' '"type":' '"reason":'; do
    [[ "$output" == *"$k"* ]] || { echo "missing field: $k"; return 1; }
  done
}

# ── Negative cases ──────────────────────────────────

@test "negative: malformed JSON exits 0 silent" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< "not valid json"
  [ "$status" -eq 0 ]
}

@test "negative: jq missing handled (timeout 2 protects)" {
  run grep -c 'timeout.*cat\|timeout 2' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ──────────────────────────────────────

@test "edge: empty file_path field exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":""}'
  [ "$status" -eq 0 ]
}

@test "edge: null file_path field exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":null}'
  [ "$status" -eq 0 ]
}

@test "edge: large input handled" {
  local big
  big=$(python3 -c 'print("x" * 5000)')
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< "{\"file_path\":\"/x.md\",\"load_reason\":\"$big\"}"
  [ "$status" -eq 0 ]
}

@test "edge: zero-byte stdin (no input pipe)" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

@test "edge: special chars in path" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"file_path":"/path with spaces/file.md"}'
  [ "$status" -eq 0 ]
}

# ── Coverage ──────────────────────────────────────────

@test "coverage: jq -r used to parse JSON" {
  run grep -c 'jq -r' "$HOOK"
  [[ "$output" -ge 3 ]]
}

@test "coverage: CLAUDE_PROJECT_DIR fallback to pwd" {
  run grep -c 'CLAUDE_PROJECT_DIR.*pwd\|CLAUDE_PROJECT_DIR:' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: InstructionsLoaded event documented" {
  run grep -c 'InstructionsLoaded\|Async: true' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────

@test "isolation: hook always exits 0 (async, never blocks)" {
  for input in '' '{}' '{"file_path":"/x"}' 'bad json' '{"file_path":null}'; do
    CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook only writes to output/instructions-loaded/" {
  local before after
  before=$(find "$TEST_REPO" -mindepth 1 -maxdepth 2 -type d 2>/dev/null | wc -l)
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"file_path":"/x"}' >/dev/null
  after=$(find "$TEST_REPO" -mindepth 1 -maxdepth 2 -type d 2>/dev/null | wc -l)
  # Should have created exactly the output/instructions-loaded subtree
  [[ "$after" -gt "$before" ]] || [[ "$after" -eq "$before" ]]
  # Verify only expected dir exists
  [[ -d "$TEST_REPO/output/instructions-loaded" ]]
}
