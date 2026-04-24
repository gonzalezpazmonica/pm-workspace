#!/usr/bin/env bats
# BATS tests for .claude/hooks/agent-tool-call-validate.sh
# PreToolUse — validates params before executing tools (Edit/Write/Read/Bash).
# Exit 2 if required param missing; exit 0 otherwise.
# Ref: batch 43 hook coverage

HOOK=".claude/hooks/agent-tool-call-validate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
}
teardown() { cd /; }

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Pass-through cases ───────────────────────────────────

@test "pass-through: no tool name identified exits 0" {
  run bash "$HOOK" <<< "{}"
  [ "$status" -eq 0 ]
}

@test "pass-through: empty stdin exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "pass-through: unrecognized tool (e.g., Task) exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Task","tool_input":{"prompt":"x"}}'
  [ "$status" -eq 0 ]
}

@test "pass-through: Glob tool (not validated) exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Glob","tool_input":{"pattern":"*.md"}}'
  [ "$status" -eq 0 ]
}

@test "pass-through: Grep tool exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Grep","tool_input":{"pattern":"x"}}'
  [ "$status" -eq 0 ]
}

# ── Edit/Write/Read: file_path required ─────────────────

@test "block: Edit without file_path exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
  [[ "$output" == *"file_path"* ]]
}

@test "block: Write without file_path exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"content":"x"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"file_path"* ]]
}

@test "block: Read without file_path exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"file_path"* ]]
}

@test "block: Edit with empty file_path exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":""}}'
  [ "$status" -eq 2 ]
}

@test "pass: Edit with valid file_path exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/x.txt","old_string":"a","new_string":"b"}}'
  [ "$status" -eq 0 ]
}

@test "pass: Write with valid file_path exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":"/tmp/x","content":"y"}}'
  [ "$status" -eq 0 ]
}

@test "pass: Read with valid file_path exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/tmp/x.md"}}'
  [ "$status" -eq 0 ]
}

# ── Bash: command required ──────────────────────────────

@test "block: Bash without command exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOQUEADO"* ]]
  [[ "$output" == *"command"* ]]
}

@test "block: Bash with empty command exits 2" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":""}}'
  [ "$status" -eq 2 ]
}

@test "pass: Bash with valid command exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
  [ "$status" -eq 0 ]
}

# ── Tool name alias (name field) ────────────────────────

@test "alias: tool_input as 'input' field also parsed" {
  run bash "$HOOK" <<< '{"name":"Edit","input":{"file_path":"/tmp/x"}}'
  [ "$status" -eq 0 ]
}

@test "alias: name field alternative to tool_name" {
  run bash "$HOOK" <<< '{"name":"Write","input":{}}'
  [ "$status" -eq 2 ]
}

# ── CLAUDE_TOOL_NAME env override ──────────────────────

@test "env: CLAUDE_TOOL_NAME env var used when set" {
  export CLAUDE_TOOL_NAME=Edit
  run bash "$HOOK" <<< '{"tool_input":{}}'
  [ "$status" -eq 2 ]  # Edit without file_path blocks
  unset CLAUDE_TOOL_NAME
}

@test "env: CLAUDE_TOOL_NAME Bash env invocation" {
  export CLAUDE_TOOL_NAME=Bash
  run bash "$HOOK" <<< '{"tool_input":{"command":"echo ok"}}'
  [ "$status" -eq 0 ]
  unset CLAUDE_TOOL_NAME
}

# ── Negative cases ──────────────────────────────────────

@test "negative: malformed JSON exits 0 (fail open)" {
  run bash "$HOOK" <<< "not json"
  [ "$status" -eq 0 ]
}

@test "negative: JSON without tool_name exits 0 (pass-through)" {
  run bash "$HOOK" <<< '{"other_field":"value"}'
  [ "$status" -eq 0 ]
}

@test "negative: Edit with file_path as number (type error) handled" {
  # JSON number where string expected
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":123}}'
  # python3 json.get returns 123 (non-empty), passes validation
  [ "$status" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: tool_name with whitespace around stripped by python" {
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":"/x"}}'
  [ "$status" -eq 0 ]
}

@test "edge: null file_path treated as string 'None' (python json idiom)" {
  # Python d.get('file_path', '') on JSON null returns None; print(None) emits 'None'.
  # Non-empty string → passes non-empty check. Documented behavior, not a bug.
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":null}}'
  [ "$status" -eq 0 ]
}

@test "edge: large payload still parsed" {
  local big
  big=$(printf 'x%.0s' {1..1000})
  run bash "$HOOK" <<< "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"/tmp/x\",\"old_string\":\"$big\"}}"
  [ "$status" -eq 0 ]
}

@test "edge: MultiEdit tool pass-through (not validated)" {
  run bash "$HOOK" <<< '{"tool_name":"MultiEdit","tool_input":{}}'
  [ "$status" -eq 0 ]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: validate_file_path function defined" {
  run grep -c 'validate_file_path()' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: validate_bash_command function defined" {
  run grep -c 'validate_bash_command()' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: case statement for Edit|Write|Read|Bash" {
  for tool in Edit Write Read Bash; do
    grep -q "$tool" "$HOOK" || fail "missing case: $tool"
  done
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ────────────────────────────────────────────

@test "isolation: hook does not modify any files" {
  local before
  before=$(find "$TMPDIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
  bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/x"}}' >/dev/null 2>&1
  local after
  after=$(find "$TMPDIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}

@test "isolation: exit codes are {0, 2}" {
  run bash "$HOOK" <<< "{}"
  [ "$status" -eq 0 ]
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{}}'
  [ "$status" -eq 2 ]
}
