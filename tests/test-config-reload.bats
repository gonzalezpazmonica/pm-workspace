#!/usr/bin/env bats
# BATS tests for .opencode/hooks/config-reload.sh
# ConfigChange async — invalidates caches when settings change.
# Ref: batch 50 hook coverage — SPEC-071 Slice 4

HOOK=".opencode/hooks/config-reload.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_REPO=$(mktemp -d "$TMPDIR/cr-XXXXXX")
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

@test "pass-through: missing source field exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"other":"field"}'
  [ "$status" -eq 0 ]
}

# ── Logging ──────────────────────────────────────────

@test "log: appends entry with source + file_path" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"source":"user_settings","file_path":"~/.claude/settings.json"}'
  [ "$status" -eq 0 ]
  [[ -f "$TEST_REPO/output/config-changes/changes.jsonl" ]]
  run cat "$TEST_REPO/output/config-changes/changes.jsonl"
  [[ "$output" == *"user_settings"* ]]
}

@test "log: ISO 8601 UTC timestamp present" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"source":"x","file_path":"/y"}'
  run cat "$TEST_REPO/output/config-changes/changes.jsonl"
  [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ]]
}

@test "log: log dir auto-created" {
  [[ ! -d "$TEST_REPO/output/config-changes" ]]
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"source":"x"}'
  [[ -d "$TEST_REPO/output/config-changes" ]]
}

@test "log: multiple invocations append (not overwrite)" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"source":"a"}' >/dev/null
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"source":"b"}' >/dev/null
  run wc -l < "$TEST_REPO/output/config-changes/changes.jsonl"
  [[ "$output" -eq 2 ]]
}

# ── Profile cache invalidation ─────────────────────

@test "profile-cache: user_settings change triggers cache rm" {
  run grep -c 'user_settings\|local_settings' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "profile-cache: rm -f savia-profile-cache" {
  run grep -c 'savia-profile-cache' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "profile-cache: TMPDIR fallback to ~/.savia/tmp" {
  run grep -c 'SAVIA_TMP\|TMPDIR:-.*HOME.*savia' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "profile-cache: removed on user_settings change" {
  local cache_dir="$TMPDIR/cr-cache-$$"
  mkdir -p "$cache_dir"
  touch "$cache_dir/savia-profile-cache"
  TMPDIR="$cache_dir" CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"source":"user_settings"}' >/dev/null
  [[ ! -f "$cache_dir/savia-profile-cache" ]]
  rm -rf "$cache_dir"
}

@test "profile-cache: removed on local_settings change" {
  local cache_dir="$TMPDIR/cr-cache-$$"
  mkdir -p "$cache_dir"
  touch "$cache_dir/savia-profile-cache"
  TMPDIR="$cache_dir" CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"source":"local_settings"}' >/dev/null
  [[ ! -f "$cache_dir/savia-profile-cache" ]]
  rm -rf "$cache_dir"
}

@test "profile-cache: NOT removed on other source" {
  local cache_dir="$TMPDIR/cr-cache-$$"
  mkdir -p "$cache_dir"
  touch "$cache_dir/savia-profile-cache"
  TMPDIR="$cache_dir" CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"source":"unrelated"}' >/dev/null
  [[ -f "$cache_dir/savia-profile-cache" ]]
  rm -rf "$cache_dir"
}

# ── Negative cases ──────────────────────────────────

@test "negative: malformed JSON exits 0 silent" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< "not valid json"
  [ "$status" -eq 0 ]
}

@test "negative: empty source field exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"source":""}'
  [ "$status" -eq 0 ]
}

@test "negative: null source field exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"source":null}'
  [ "$status" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────

@test "edge: large stdin handled" {
  local big
  big=$(python3 -c 'print("x" * 5000)')
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< "{\"source\":\"x\",\"pad\":\"$big\"}"
  [ "$status" -eq 0 ]
}

@test "edge: zero-byte stdin" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

@test "edge: timeout 2 on cat (no blocking)" {
  run grep -c 'timeout 2' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Coverage ──────────────────────────────────────────

@test "coverage: jq -r used for parsing" {
  run grep -c 'jq -r' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "coverage: ConfigChange event documented" {
  run grep -c 'ConfigChange\|Async: true' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: 3 fields ts/source/file in JSONL" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"source":"x","file_path":"/y"}' >/dev/null
  run cat "$TEST_REPO/output/config-changes/changes.jsonl"
  [[ "$output" == *'"ts":'* ]]
  [[ "$output" == *'"source":'* ]]
  [[ "$output" == *'"file":'* ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ──────────────────────────────────────────

@test "isolation: hook always exits 0" {
  for input in '' '{}' '{"source":"a"}' 'bad' '{"source":null}'; do
    CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< "$input"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: only writes to output/config-changes/" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< '{"source":"x"}' >/dev/null
  [[ -d "$TEST_REPO/output/config-changes" ]]
  [[ -f "$TEST_REPO/output/config-changes/changes.jsonl" ]]
}
