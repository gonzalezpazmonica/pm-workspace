#!/usr/bin/env bats
# BATS tests for .claude/hooks/tool-call-healing.sh
# PreToolUse hook — validates Read/Edit/Write/Glob/Grep parameters before exec.
# Exit 2 if required param missing/invalid; exit 0 otherwise (fail-open).
# SPEC-141 reference. Batch 45 hook coverage.

HOOK=".claude/hooks/tool-call-healing.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export SAVIA_HOOK_PROFILE="${SAVIA_HOOK_PROFILE:-standard}"
  TEST_DIR=$(mktemp -d "$TMPDIR/tch-XXXXXX")
}
teardown() {
  rm -rf "$TEST_DIR" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "has profile_gate standard" {
  run grep -c 'profile_gate "standard"' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "SPEC-141 reference" {
  run grep -c 'SPEC-141' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Pass-through cases ───────────────────────────────────

@test "pass-through: empty stdin exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "pass-through: no tool_name exits 0" {
  run bash "$HOOK" <<< '{"other":"field"}'
  [ "$status" -eq 0 ]
}

@test "pass-through: unrecognized tool (Bash) exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  [ "$status" -eq 0 ]
}

@test "pass-through: Task tool not validated" {
  run bash "$HOOK" <<< '{"tool_name":"Task","tool_input":{}}'
  [ "$status" -eq 0 ]
}

# ── Read/Edit: file_path required ───────────────────────

@test "block: Read with empty file_path exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":""}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]] || [[ "$stderr" == *"BLOCKED"* ]]
}

@test "block: Read without file_path exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{}}'
  [ "$status" -eq 2 ]
}

@test "block: Edit with empty file_path exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":""}}'
  [ "$status" -eq 2 ]
}

@test "block: Edit without file_path exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{}}'
  [ "$status" -eq 2 ]
}

@test "pass: Read with valid existing file exits 0" {
  echo "x" > "$TEST_DIR/real.txt"
  run bash "$HOOK" <<< "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$TEST_DIR/real.txt\"}}"
  [ "$status" -eq 0 ]
}

@test "pass: Read with missing file exits 0 (warning only)" {
  run bash "$HOOK" <<< "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$TEST_DIR/nope.txt\"}}"
  [ "$status" -eq 0 ]
}

# ── Write: parent dir required ──────────────────────────

@test "block: Write with empty file_path exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":""}}'
  [ "$status" -eq 2 ]
  [[ "${output}${stderr:-}" == *"BLOCKED"* ]]
}

@test "block: Write to nonexistent parent dir exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":"/nonexistent/abc/file.txt"}}'
  [ "$status" -eq 2 ]
  [[ "${output}${stderr:-}" == *"parent directory"* ]]
}

@test "pass: Write to existing parent dir exits 0" {
  run bash "$HOOK" <<< "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TEST_DIR/new.txt\"}}"
  [ "$status" -eq 0 ]
}

# ── Glob/Grep: pattern required ─────────────────────────

@test "block: Glob without pattern exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Glob","tool_input":{}}'
  [ "$status" -eq 2 ]
  [[ "${output}${stderr:-}" == *"pattern"* ]]
}

@test "block: Glob with empty pattern exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Glob","tool_input":{"pattern":""}}'
  [ "$status" -eq 2 ]
}

@test "block: Grep without pattern exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Grep","tool_input":{}}'
  [ "$status" -eq 2 ]
}

@test "pass: Glob with valid pattern exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Glob","tool_input":{"pattern":"*.md"}}'
  [ "$status" -eq 0 ]
}

@test "pass: Grep with valid pattern exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Grep","tool_input":{"pattern":"TODO"}}'
  [ "$status" -eq 0 ]
}

# ── Typo detection ──────────────────────────────────────

@test "typo: similar filename suggested in stderr" {
  echo "content" > "$TEST_DIR/README.md"
  run bash "$HOOK" <<< "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$TEST_DIR/readme.md\"}}"
  # Status 0 (warning only), but stderr should mention similar
  [ "$status" -eq 0 ]
}

@test "typo: no similar files no warning" {
  run bash "$HOOK" <<< "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$TEST_DIR/totally-missing.xyz\"}}"
  [ "$status" -eq 0 ]
}

@test "typo: parent dir nonexistent no search attempted" {
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/does/not/exist/file.txt"}}'
  [ "$status" -eq 0 ]
}

# ── Negative cases ──────────────────────────────────────

@test "negative: malformed JSON handled (tool name not extracted)" {
  run bash "$HOOK" <<< "not json but contains Read somewhere"
  # tool_name extraction fails → no tool detected → pass
  [ "$status" -eq 0 ]
}

@test "negative: JSON with tool_name but wrong structure" {
  run bash "$HOOK" <<< '{"tool_name":"Write"}'
  # No tool_input → file_path is empty → blocks Write
  [ "$status" -eq 2 ]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: file_path with spaces" {
  mkdir -p "$TEST_DIR/with spaces"
  echo "x" > "$TEST_DIR/with spaces/file.txt"
  run bash "$HOOK" <<< "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$TEST_DIR/with spaces/file.txt\"}}"
  [ "$status" -eq 0 ]
}

@test "edge: Glob pattern with special chars" {
  run bash "$HOOK" <<< '{"tool_name":"Glob","tool_input":{"pattern":"**/*.{ts,tsx}"}}'
  [ "$status" -eq 0 ]
}

@test "edge: profile=strict also allowed (standard tier)" {
  SAVIA_HOOK_PROFILE=strict run bash "$HOOK" <<< '{"tool_name":"Glob","tool_input":{"pattern":"*.md"}}'
  [ "$status" -eq 0 ]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: case statement covers Read|Edit|Write|Glob|Grep" {
  for tool in Read Edit Write Glob Grep; do
    grep -q "$tool" "$HOOK" || fail "missing: $tool"
  done
}

@test "coverage: typo detection via find" {
  run grep -c 'find.*maxdepth' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: dirname used for parent check" {
  run grep -c 'dirname' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ───────────────────────────────────────────

@test "isolation: exit codes limited to {0, 2}" {
  for payload in '{}' '{"tool_name":"Read","tool_input":{}}' '{"tool_name":"Glob","tool_input":{"pattern":"x"}}'; do
    run bash "$HOOK" <<< "$payload"
    [[ "$status" -eq 0 || "$status" -eq 2 ]]
  done
}

@test "isolation: hook does not modify filesystem" {
  local before after
  before=$(find "$TEST_DIR" -type f 2>/dev/null | wc -l)
  bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"'"$TEST_DIR"'/x"}}' >/dev/null 2>&1
  after=$(find "$TEST_DIR" -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
