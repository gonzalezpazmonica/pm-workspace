#!/usr/bin/env bats
# BATS tests for .opencode/hooks/live-progress-hook.sh
# PreToolUse async — logs every tool use to ~/.savia/live.log
# Tier: observability. Never blocks.
# Ref: batch 46 hook coverage — SPEC-013 live observability feed

HOOK=".opencode/hooks/live-progress-hook.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_HOME=$(mktemp -d "$TMPDIR/lph-home-XXXXXX")
}
teardown() {
  rm -rf "$TEST_HOME" 2>/dev/null || true
  cd /
}

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Pass-through ────────────────────────────────────────

@test "pass-through: empty stdin (no tool_name) exits 0" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< "{}"
  [ "$status" -eq 0 ]
}

@test "pass-through: no JSON exits 0" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

# ── Bash tool ───────────────────────────────────────────

@test "Bash: command description logged" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"ls -la","description":"List files"}}'
  [ "$status" -eq 0 ]
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Ejecutando"* ]]
  [[ "$output" == *"List files"* ]]
}

@test "Bash: fallback to command when no description" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"pwd"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"pwd"* ]]
}

# ── Edit/Write/Read ─────────────────────────────────────

@test "Edit: file basename logged" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":"/home/x/myfile.sh"}}'
  [ "$status" -eq 0 ]
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Editando"* ]]
  [[ "$output" == *"myfile.sh"* ]]
  [[ "$output" != *"/home/x/"* ]]
}

@test "Write: file basename logged" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":"/a/b/newfile.md"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Escribiendo"* ]]
  [[ "$output" == *"newfile.md"* ]]
}

@test "Read: file basename logged" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/some/path/readme.txt"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Leyendo"* ]]
  [[ "$output" == *"readme.txt"* ]]
}

# ── Agent/Glob/Grep/Skill ───────────────────────────────

@test "Agent: description logged" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Agent","tool_input":{"description":"Explore codebase"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Agente"* ]]
  [[ "$output" == *"Explore"* ]]
}

@test "Agent: fallback to prompt when no description" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Agent","tool_input":{"prompt":"Do the task"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Do the task"* ]]
}

@test "Glob: pattern logged" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Glob","tool_input":{"pattern":"*.sh"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Buscando"* ]]
  [[ "$output" == *"*.sh"* ]]
}

@test "Grep: pattern logged" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Grep","tool_input":{"pattern":"TODO"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Grep"* ]]
  [[ "$output" == *"TODO"* ]]
}

@test "Skill: skill name logged" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Skill","tool_input":{"skill":"pr-plan"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Skill"* ]]
  [[ "$output" == *"pr-plan"* ]]
}

# ── Task* pattern ───────────────────────────────────────

@test "Task: TaskCreate matches wildcard pattern" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"TaskCreate","tool_input":{"description":"new task"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Task"* ]]
  [[ "$output" == *"TaskCreate"* ]]
}

@test "Task: TaskUpdate matches wildcard pattern" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"TaskUpdate","tool_input":{"status":"completed"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"Task"* ]]
  [[ "$output" == *"TaskUpdate"* ]]
}

# ── Unknown tools ───────────────────────────────────────

@test "fallback: unknown tool logged with name only" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"WeirdTool","tool_input":{"foo":"bar"}}'
  [ "$status" -eq 0 ]
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"WeirdTool"* ]]
}

# ── Log rotation ────────────────────────────────────────

@test "rotation: log truncated when >500 lines" {
  mkdir -p "$TEST_HOME/.savia"
  # Pre-fill with 501 lines
  for i in $(seq 1 501); do echo "line-$i"; done > "$TEST_HOME/.savia/live.log"
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/x.md"}}' >/dev/null 2>&1
  local n
  n=$(wc -l < "$TEST_HOME/.savia/live.log")
  [[ "$n" -le 251 ]]  # tail -250 + new line
}

@test "rotation: log under 500 lines not rotated" {
  mkdir -p "$TEST_HOME/.savia"
  for i in $(seq 1 100); do echo "line-$i"; done > "$TEST_HOME/.savia/live.log"
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/x.md"}}' >/dev/null 2>&1
  local n
  n=$(wc -l < "$TEST_HOME/.savia/live.log")
  [[ "$n" -eq 101 ]]
}

# ── Log format ──────────────────────────────────────────

@test "format: log entry has HH:MM:SS timestamp" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/x.md"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" =~ \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] ]]
}

@test "format: description truncated to 80 chars for Bash" {
  local long_desc
  long_desc=$(printf 'x%.0s' {1..200})
  HOME="$TEST_HOME" run bash "$HOOK" <<< "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\",\"description\":\"$long_desc\"}}"
  run cat "$TEST_HOME/.savia/live.log"
  # Line should be under 200 chars total (timestamp + prefix + 80 char desc)
  local line
  line=$(head -1 "$TEST_HOME/.savia/live.log")
  [[ "${#line}" -lt 200 ]]
}

# ── Error handling ──────────────────────────────────────

@test "error: malformed JSON does not crash hook" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< "not valid json"
  [ "$status" -eq 0 ]
}

@test "error: trap catches errors to hook-errors.log" {
  run grep -c 'hook-errors.log\|trap.*ERR' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: deeply nested path shows only basename" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/a/b/c/d/e/f/g/h/deep.txt"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"deep.txt"* ]]
  [[ "$output" != *"/a/b/c/"* ]]
}

@test "edge: file without extension" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/bin/bash"}}'
  run cat "$TEST_HOME/.savia/live.log"
  [[ "$output" == *"bash"* ]]
}

@test "edge: .savia dir auto-created" {
  [[ ! -d "$TEST_HOME/.savia" ]]
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/x.md"}}'
  [[ -d "$TEST_HOME/.savia" ]]
}

@test "edge: null tool_input handled" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":null}'
  [ "$status" -eq 0 ]
}

@test "edge: large command description does not overflow log" {
  local big
  big=$(printf 'x%.0s' {1..1500})
  HOME="$TEST_HOME" run bash "$HOOK" <<< "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$big\"}}"
  [ "$status" -eq 0 ]
  local line_len
  line_len=$(wc -L < "$TEST_HOME/.savia/live.log")
  [[ "$line_len" -lt 300 ]]
}

@test "edge: no-arg tool (empty tool_input) handled" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{}}'
  [ "$status" -eq 0 ]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: 8+ tool cases in switch" {
  for tool in Bash Edit Write Read Agent Glob Grep Skill; do
    grep -q "$tool)" "$HOOK" || fail "missing case: $tool"
  done
}

@test "coverage: rotation threshold 500 present" {
  run grep -c '500' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: jq parse for tool_name" {
  run grep -c 'jq -r' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ───────────────────────────────────────────

@test "isolation: hook never blocks (exit always 0)" {
  for payload in '' '{}' '{"tool_name":"X"}' 'bad json' '{"tool_name":"Bash","tool_input":{"command":"x"}}'; do
    HOME="$TEST_HOME" run bash "$HOOK" <<< "$payload"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook does not modify repo" {
  local before after
  before=$(find . -maxdepth 2 -type f 2>/dev/null | wc -l)
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"/x"}}' >/dev/null 2>&1
  after=$(find . -maxdepth 2 -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
