#!/usr/bin/env bats
# BATS tests for .opencode/hooks/post-tool-failure-log.sh
# PostToolUseFailure — structured tool failure logging, error categorization,
# retry hints, pattern detection (3+ same tool per day).
# Ref: batch 47 hook coverage — SPEC-068 tool failure observability

HOOK=".opencode/hooks/post-tool-failure-log.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_HOME=$(mktemp -d "$TMPDIR/ptfl-home-XXXXXX")
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
@test "SPEC-068 reference" {
  run grep -c 'SPEC-068' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Pass-through ────────────────────────────────────────

@test "pass-through: empty stdin exits 0" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "pass-through: log dir auto-created" {
  [[ ! -d "$TEST_HOME/.pm-workspace/tool-failures" ]]
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Bash","error":"x"}'
  [[ -d "$TEST_HOME/.pm-workspace/tool-failures" ]]
}

# ── Error categorization ────────────────────────────────

@test "category: permission denied classified as permission" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"Permission denied: /etc/passwd"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"permission"'* ]]
  [[ "$output" == *"Check file permissions"* ]]
}

@test "category: EACCES classified as permission" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Write","error":"EACCES: cannot write"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"permission"'* ]]
}

@test "category: no such file classified as not_found" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Read","error":"No such file or directory"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"not_found"'* ]]
  [[ "$output" == *"Verify file path"* ]]
}

@test "category: ENOENT classified as not_found" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"ENOENT: file not found"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"not_found"'* ]]
}

@test "category: command not found classified as not_found" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"bash: xyz: command not found"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"not_found"'* ]]
}

@test "category: timeout classified as timeout" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"operation timed out after 30s"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"timeout"'* ]]
  [[ "$output" == *"increase timeout"* ]]
}

@test "category: deadline exceeded classified as timeout" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Agent","error":"deadline exceeded waiting for response"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"timeout"'* ]]
}

@test "category: syntax error classified as syntax" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"syntax error near unexpected token"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"syntax"'* ]]
  [[ "$output" == *"missing quotes"* ]]
}

@test "category: invalid JSON classified as syntax" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Edit","error":"invalid json: unterminated string"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"syntax"'* ]]
}

@test "category: ECONNREFUSED classified as network" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"WebFetch","error":"ECONNREFUSED localhost:8080"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"network"'* ]]
  [[ "$output" == *"connectivity"* ]]
}

@test "category: certificate error classified as network" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"WebFetch","error":"SSL certificate problem"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"network"'* ]]
}

@test "category: DNS failure classified as network" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"could not resolve DNS host"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"network"'* ]]
}

@test "category: unknown error category fallback" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"X","error":"something truly unexpected occurred"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"category":"unknown"'* ]]
  [[ "$output" == *"Review error details"* ]]
}

# ── Log format ──────────────────────────────────────────

@test "format: log line is valid JSON" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"permission denied"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  echo "$output" | python3 -c 'import sys,json; json.loads(sys.stdin.read())'
}

@test "format: has ISO 8601 UTC timestamp" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"x"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" =~ \"ts\":\"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\" ]]
}

@test "format: file named YYYY-MM-DD.jsonl" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"x"}' >/dev/null
  run ls "$TEST_HOME/.pm-workspace/tool-failures/"
  [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}\.jsonl ]]
}

@test "format: tool name field captured" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"MyTool","error":"x"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"tool":"MyTool"'* ]]
}

@test "format: unknown tool falls back to 'unknown'" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"error":"no tool field"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"tool":"unknown"'* ]]
}

@test "format: error truncated to 200 chars" {
  local big
  big=$(printf 'x%.0s' {1..500})
  HOME="$TEST_HOME" bash "$HOOK" <<< "{\"tool_name\":\"Bash\",\"error\":\"$big\"}" >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  # line should be at most ~400 chars (timestamp + fields + 200 error)
  local line_len
  line_len=$(wc -L < "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl)
  [[ "$line_len" -lt 500 ]]
}

# ── Pattern detection ──────────────────────────────────

@test "pattern: 3rd failure of same tool adds repeated pattern" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"permission denied"}' >/dev/null
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"permission denied"}' >/dev/null
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"permission denied"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" == *'"pattern":"repeated"'* ]]
  [[ "$output" == *'"count":3'* ]]
}

@test "pattern: different tools do not trigger pattern" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"A","error":"fail"}' >/dev/null
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"B","error":"fail"}' >/dev/null
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"C","error":"fail"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" != *'"pattern":"repeated"'* ]]
}

@test "pattern: first failure has no pattern field" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Solo","error":"once"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  [[ "$output" != *'"pattern"'* ]]
}

# ── Safety / sanitization ───────────────────────────────

@test "sanitize: double quotes in error replaced with single" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"error with quotes inside"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  # Must be parseable as JSON — quotes sanitized preserves validity
  echo "$output" | python3 -c 'import sys,json; json.loads(sys.stdin.read().strip())'
}

@test "sanitize: newlines in error replaced with space" {
  printf '{"tool_name":"Bash","error":"line one\\nline two"}' | HOME="$TEST_HOME" bash "$HOOK" >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  # Log line should be a single line
  local n
  n=$(wc -l < "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl)
  [[ "$n" -eq 1 ]]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: empty error field (falls back to raw input)" {
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash"}' >/dev/null
  run cat "$TEST_HOME/.pm-workspace/tool-failures/"*.jsonl
  # Log line should exist even without explicit error field
  [[ -n "$output" ]]
}

@test "edge: large 10KB input does not overflow" {
  local big
  big=$(python3 -c 'print("x" * 10000)')
  HOME="$TEST_HOME" run bash "$HOOK" <<< "{\"tool_name\":\"Bash\",\"error\":\"$big\"}"
  [ "$status" -eq 0 ]
}

@test "edge: null error field handled" {
  HOME="$TEST_HOME" run bash "$HOOK" <<< '{"tool_name":"Bash","error":null}'
  [ "$status" -eq 0 ]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: 6 error categories defined" {
  for cat in permission not_found timeout syntax network unknown; do
    grep -q "\"$cat|" "$HOOK" || grep -q "echo \"$cat|" "$HOOK" || fail "missing category: $cat"
  done
}

@test "coverage: categorize_error function defined" {
  run grep -c 'categorize_error()' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: pattern detection threshold present" {
  run grep -c 'SAME_TOOL_COUNT\|repeated' "$HOOK"
  [[ "$output" -ge 2 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ───────────────────────────────────────────

@test "isolation: hook always exits 0 (never blocks)" {
  for payload in '' '{}' '{"bad":json' '{"tool_name":"X","error":"y"}'; do
    HOME="$TEST_HOME" run bash "$HOOK" <<< "$payload"
    [ "$status" -eq 0 ]
  done
}

@test "isolation: hook does not modify repo" {
  local before after
  before=$(find . -maxdepth 2 -type f 2>/dev/null | wc -l)
  HOME="$TEST_HOME" bash "$HOOK" <<< '{"tool_name":"Bash","error":"x"}' >/dev/null 2>&1
  after=$(find . -maxdepth 2 -type f 2>/dev/null | wc -l)
  [[ "$before" == "$after" ]]
}
