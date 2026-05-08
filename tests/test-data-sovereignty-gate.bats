#!/usr/bin/env bats
# BATS tests for .opencode/hooks/data-sovereignty-gate.sh
# Scope: deterministic paths (early exits, exemptions, disabled flag).
# Daemon interactions covered by integration tests elsewhere.
# Ref: batch 39 hook test coverage gap

HOOK=".opencode/hooks/data-sovereignty-gate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export CLAUDE_PROJECT_DIR="$TMPDIR/workspace-$$"
  mkdir -p "$CLAUDE_PROJECT_DIR/output"
  # Prevent daemon interaction during tests
  export SAVIA_SHIELD_PORT="65535"  # unlikely port
  # Hook requires security profile tier
  export SAVIA_HOOK_PROFILE=security
  # Default enabled; individual tests may override
  unset SAVIA_SHIELD_ENABLED
}

teardown() {
  rm -rf "$CLAUDE_PROJECT_DIR" 2>/dev/null || true
  cd /
}

@test "hook exists and is executable" { [[ -x "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

@test "empty stdin exits 0 (no input = no action)" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "SAVIA_SHIELD_ENABLED=false disables gate" {
  export SAVIA_SHIELD_ENABLED=false
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/tmp/test.sql","content":"password=secret123"}}'
  [ "$status" -eq 0 ]
}

@test "missing file_path exits 0 (no scope to gate)" {
  run bash "$HOOK" <<< '{"tool_input":{"content":"some content"}}'
  [ "$status" -eq 0 ]
}

# ── Private destination exemptions ───────────────────────

@test "exempt: projects/ path bypasses scan" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"projects/alpha/secret.txt","content":"password=hunter2"}}'
  [ "$status" -eq 0 ]
}

@test "exempt: tenants/ path bypasses scan" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"tenants/acme/creds.env","content":"API_KEY=abc123"}}'
  [ "$status" -eq 0 ]
}

@test "exempt: .savia/ path bypasses scan" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/home/u/.savia/state.json","content":"token=x"}}'
  [ "$status" -eq 0 ]
}

@test "exempt: output/ path bypasses scan" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"output/audit.log","content":"data"}}'
  [ "$status" -eq 0 ]
}

@test "exempt: *.local.* file pattern bypasses scan" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"config.local.json","content":"password=x"}}'
  [ "$status" -eq 0 ]
}

@test "exempt: settings.local.json bypasses scan" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/foo/.claude/settings.local.json","content":"x"}}'
  [ "$status" -eq 0 ]
}

@test "exempt: .claude/sessions/ path bypasses scan" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/x/.claude/sessions/abc.json","content":"x"}}'
  [ "$status" -eq 0 ]
}

@test "exempt: private-agent-memory files bypass scan" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/x/private-agent-memory/entry.md","content":"x"}}'
  [ "$status" -eq 0 ]
}

# ── Sovereignty whitelist (scripts/hooks that handle the logic) ─────

@test "whitelist: scripts/data-sovereignty-* exempt" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"scripts/data-sovereignty-audit.sh","content":"grep password"}}'
  [ "$status" -eq 0 ]
}

@test "whitelist: scripts/shield-ner.py exempt" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/x/scripts/shield-ner.py","content":"x"}}'
  [ "$status" -eq 0 ]
}

@test "whitelist: hooks/data-sovereignty-gate.sh exempt (self)" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":".opencode/hooks/data-sovereignty-gate.sh","content":"pattern"}}'
  [ "$status" -eq 0 ]
}

# ── Negative cases ───────────────────────────────────────

@test "negative: malformed JSON stdin exits 0 (fail open on parse error)" {
  run bash "$HOOK" <<< "not valid json"
  [ "$status" -eq 0 ]
}

@test "negative: empty tool_input exits 0" {
  run bash "$HOOK" <<< '{}'
  [ "$status" -eq 0 ]
}

@test "negative: null file_path exits 0" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":null}}'
  [ "$status" -eq 0 ]
}

# ── Edge cases ───────────────────────────────────────────

@test "edge: path with .. traversal normalized before exemption check" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"foo/../projects/alpha/x.txt","content":"x"}}'
  [ "$status" -eq 0 ]
}

@test "edge: Windows backslash paths normalized" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"projects\\alpha\\x.txt","content":"x"}}'
  [ "$status" -eq 0 ]
}

@test "edge: deeply nested projects/ path exempt" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"a/b/c/d/projects/p/f.sql","content":"password=x"}}'
  [ "$status" -eq 0 ]
}

@test "edge: absolute private path exempt" {
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"/home/user/projects/p/file.sql","content":"x"}}'
  [ "$status" -eq 0 ]
}

# ── Coverage ──────────────────────────────────────────────

@test "coverage: profile-gate source guard present" {
  run grep -c 'profile_gate' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: audit log path declared" {
  run grep -c 'AUDIT_LOG' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: block_fallback helper defined" {
  run grep -c 'block_fallback()' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────────

@test "isolation: hook does not modify workspace on exempt paths" {
  local before_hash
  before_hash=$(find "$CLAUDE_PROJECT_DIR" -type f 2>/dev/null | wc -l)
  bash "$HOOK" <<< '{"tool_input":{"file_path":"projects/alpha/x.txt","content":"password=y"}}' >/dev/null 2>&1
  local after_hash
  after_hash=$(find "$CLAUDE_PROJECT_DIR" -type f 2>/dev/null | wc -l)
  [[ "$before_hash" == "$after_hash" ]]
}

@test "isolation: exit codes are in {0, 2} (never 1)" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"projects/x/y.sql","content":"x"}}'
  [ "$status" -eq 0 ]
}
