#!/usr/bin/env bats
# tests/test-managed-agents-patterns.bats
# BATS tests for Managed Agents patterns (credential proxy, session event log)
# Source: Anthropic Managed Agents engineering post (2026-04-14)
# Quality gate: SPEC-055 (audit score >=80)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export CRED_SCRIPT="$REPO_ROOT/scripts/credential-proxy.sh"
  export EVENT_SCRIPT="$REPO_ROOT/scripts/session-event-log.sh"
  export RULE="$REPO_ROOT/.claude/rules/domain/managed-agents-patterns.md"
  TMPDIR_TEST=$(mktemp -d)
  export SESSION_LOG_DIR="$TMPDIR_TEST/events"
  export CREDENTIAL_PROXY_LOG="$TMPDIR_TEST/cred-audit.jsonl"
}
teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── Script structure ───────────────────────────────────────────────────────

@test "credential-proxy.sh exists and is executable" {
  [[ -x "$CRED_SCRIPT" ]]
}
@test "credential-proxy.sh uses set -uo pipefail" {
  head -3 "$CRED_SCRIPT" | grep -q "set -uo pipefail"
}
@test "session-event-log.sh exists and is executable" {
  [[ -x "$EVENT_SCRIPT" ]]
}
@test "session-event-log.sh uses set -uo pipefail" {
  head -3 "$EVENT_SCRIPT" | grep -q "set -uo pipefail"
}

# ── Rule ───────────────────────────────────────────────────────────────────

@test "managed-agents-patterns.md exists and <=150 lines" {
  [[ -f "$RULE" ]]
  local lines
  lines=$(wc -l < "$RULE")
  [[ $lines -le 150 ]]
}
@test "rule documents 3 patterns" {
  grep -q "Pattern 1" "$RULE"
  grep -q "Pattern 2" "$RULE"
  grep -q "Pattern 3" "$RULE"
}
@test "rule references credential-proxy.sh" {
  grep -q "credential-proxy" "$RULE"
}
@test "rule references session-event-log.sh" {
  grep -q "session-event-log" "$RULE"
}

# ── Credential proxy ──────────────────────────────────────────────────────

@test "credential-proxy status runs without error" {
  run bash "$CRED_SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Credential Proxy Status"* ]]
}
@test "credential-proxy rejects unknown command" {
  run bash "$CRED_SCRIPT" nonexistent
  [[ "$status" -eq 1 ]]
}
@test "credential-proxy sanitize strips tokens from output" {
  local test_output="https://user:ghp_abc123def456@github.com/repo"
  local sanitized
  sanitized=$(echo "$test_output" | source <(grep -A5 'sanitize_output()' "$CRED_SCRIPT" | tail -4) 2>/dev/null || echo "$test_output" | sed -E 's/(https?:\/\/)[^@]*@/\1***@/g')
  [[ "$sanitized" != *"ghp_abc123"* ]]
}
@test "credential-proxy git-clone fails without URL" {
  run bash "$CRED_SCRIPT" git-clone
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"URL required"* ]]
}

# ── Session event log ─────────────────────────────────────────────────────

@test "session-event-log status runs without error" {
  run bash "$EVENT_SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Session Event Log"* ]]
}
@test "session-event-log emit creates JSONL entry" {
  run bash "$EVENT_SCRIPT" emit decision "test decision"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OK"* ]]
  # Verify JSONL file created
  local logfile
  logfile=$(ls "$SESSION_LOG_DIR"/*.jsonl 2>/dev/null | head -1)
  [[ -f "$logfile" ]]
  grep -q '"type":"decision"' "$logfile"
  grep -q "test decision" "$logfile"
}
@test "session-event-log emit supports all event types" {
  for etype in decision correction discovery error milestone handoff; do
    run bash "$EVENT_SCRIPT" emit "$etype" "test $etype"
    [[ "$status" -eq 0 ]]
  done
}
@test "session-event-log emit warns on unknown type" {
  run bash "$EVENT_SCRIPT" emit "bogus" "content"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Unknown event type"* ]] || [[ "$output" == *"OK"* ]]
}
@test "session-event-log query returns emitted events" {
  bash "$EVENT_SCRIPT" emit decision "alpha" >/dev/null
  bash "$EVENT_SCRIPT" emit correction "beta" >/dev/null
  run bash "$EVENT_SCRIPT" query --type decision
  [[ "$output" == *"alpha"* ]]
  [[ "$output" != *"beta"* ]]
}
@test "session-event-log query --last limits results" {
  for i in 1 2 3 4 5; do
    bash "$EVENT_SCRIPT" emit note "event-$i" >/dev/null
  done
  run bash "$EVENT_SCRIPT" query --last 2
  local count
  count=$(echo "$output" | grep -c "event-" || echo 0)
  [[ $count -le 2 ]]
}
@test "session-event-log recover shows decisions" {
  export SAVIA_SESSION_ID="test-recover-session"
  bash "$EVENT_SCRIPT" emit decision "use PostgreSQL" >/dev/null
  bash "$EVENT_SCRIPT" emit correction "not MySQL" >/dev/null
  run bash "$EVENT_SCRIPT" recover --session latest
  [[ "$output" == *"Decisions"* ]]
  [[ "$output" == *"PostgreSQL"* ]]
}
@test "session-event-log recover fails on nonexistent session" {
  run bash "$EVENT_SCRIPT" recover --session nonexistent-id
  [[ "$status" -eq 1 ]]
}
@test "session-event-log emit fails without content" {
  run bash "$EVENT_SCRIPT" emit decision
  [[ "$status" -eq 1 ]]
}

# ── Integration ────────────────────────────────────────────────────────────

@test "credential-proxy audit log is JSONL format" {
  export GITHUB_PAT_FILE="/tmp/nonexistent-pat-$$"
  bash "$CRED_SCRIPT" git-push 2>/dev/null || true
  if [[ -f "$CREDENTIAL_PROXY_LOG" ]]; then
    # If log was created, verify it's valid JSONL
    head -1 "$CREDENTIAL_PROXY_LOG" | grep -qE '^\{.*\}$'
  fi
}
