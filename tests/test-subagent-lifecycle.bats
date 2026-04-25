#!/usr/bin/env bats
# BATS tests for .claude/hooks/subagent-lifecycle.sh
# SubagentStart/SubagentStop async — logs agent lifecycle to jsonl.
# Ref: batch 51 hook coverage — final 3 hooks → 58/58 (100%) — SPEC-071 Slice 4.

HOOK=".claude/hooks/subagent-lifecycle.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_REPO=$(mktemp -d "$TMPDIR/sl-XXXXXX")
}
teardown() {
  rm -rf "$TEST_REPO" 2>/dev/null || true
  cd /
}

# ── Structural ────────────────────────────────────

@test "hook file exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }
@test "header: SubagentStart event documented" {
  run grep -c 'SubagentStart' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "header: SubagentStop event documented" {
  run grep -c 'SubagentStop' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "header: SPEC-071 reference" {
  run grep -c 'SPEC-071' "$HOOK"
  [[ "$output" -ge 1 ]]
}

# ── Pass-through ──────────────────────────────────

@test "pass-through: empty stdin exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "pass-through: missing event field exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"other":"field"}'
  [ "$status" -eq 0 ]
}

@test "pass-through: invalid JSON exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< 'not-json'
  [ "$status" -eq 0 ]
}

# ── SubagentStart logging ─────────────────────────

@test "start: appends start entry to jsonl" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"researcher","agent_id":"abc-123"}'
  [ "$status" -eq 0 ]
  [[ -f "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl" ]]
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" == *'"event":"start"'* ]]
}

@test "start: includes agent_type" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"explorer","agent_id":"xyz"}'
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"explorer"* ]]
}

@test "start: includes agent_id" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"a","agent_id":"unique-id-42"}'
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"unique-id-42"* ]]
}

@test "start: ISO 8601 UTC timestamp" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"a","agent_id":"i"}'
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ]]
}

# ── SubagentStop logging ──────────────────────────

@test "stop: appends stop entry to jsonl" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStop","agent_type":"r","agent_id":"i","agent_transcript_path":"/tmp/t.jsonl"}'
  [ "$status" -eq 0 ]
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" == *'"event":"stop"'* ]]
}

@test "stop: transcript path captured" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStop","agent_type":"r","agent_id":"i","agent_transcript_path":"/tmp/specific-path.jsonl"}'
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"/tmp/specific-path.jsonl"* ]]
}

@test "stop: missing transcript path → empty string" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStop","agent_type":"r","agent_id":"i"}'
  [ "$status" -eq 0 ]
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" == *'"transcript":""'* ]]
}

# ── Log directory ─────────────────────────────────

@test "log dir auto-created" {
  [[ ! -d "$TEST_REPO/output/agent-lifecycle" ]]
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"a","agent_id":"i"}'
  [[ -d "$TEST_REPO/output/agent-lifecycle" ]]
}

@test "log path: lifecycle.jsonl naming" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"a","agent_id":"i"}'
  [[ -f "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl" ]]
}

@test "append: two events accumulate without overwrite" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"a","agent_id":"1"}'
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStop","agent_type":"a","agent_id":"1"}'
  run wc -l < "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" -eq 2 ]]
}

# ── Defaults ──────────────────────────────────────

@test "default: missing agent_type → 'unknown'" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_id":"i"}'
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"unknown"* ]]
}

@test "default: missing agent_id → 'unknown'" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"a"}'
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"unknown"* ]]
}

# ── Negative cases ────────────────────────────────

@test "negative: unknown event name still passes through" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"WeirdEvent","agent_type":"a","agent_id":"i"}'
  [ "$status" -eq 0 ]
}

@test "negative: stdin timeout (3s) not blocking forever" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run timeout 5 bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

@test "negative: malformed JSON does not write log" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< 'broken{json'
  [ "$status" -eq 0 ]
  [[ ! -f "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl" ]] || \
    [[ ! -s "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl" ]]
}

# ── Edge cases ────────────────────────────────────

@test "edge: agent_id with special chars survives JSON encoding" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"x","agent_id":"id-with-dash_underscore"}'
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"id-with-dash_underscore"* ]]
}

@test "edge: empty CLAUDE_PROJECT_DIR fallback to pwd" {
  cd "$TEST_REPO"
  run bash "$BATS_TEST_DIRNAME/../$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"a","agent_id":"i"}'
  [ "$status" -eq 0 ]
  [[ -f "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl" ]]
}

# ── Isolation ─────────────────────────────────────

@test "isolation: hook always exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"a","agent_id":"i"}'
  [ "$status" -eq 0 ]
}

@test "isolation: only writes under output/agent-lifecycle/" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStart","agent_type":"a","agent_id":"i"}'
  [[ -d "$TEST_REPO/output/agent-lifecycle" ]]
  [[ ! -e "$TEST_REPO/random-file" ]]
}

@test "coverage: 5 jsonl fields ts/event/agent/id/transcript present" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"SubagentStop","agent_type":"a","agent_id":"i","agent_transcript_path":"/p"}'
  run cat "$TEST_REPO/output/agent-lifecycle/lifecycle.jsonl"
  [[ "$output" == *'"ts"'* ]]
  [[ "$output" == *'"event"'* ]]
  [[ "$output" == *'"agent"'* ]]
  [[ "$output" == *'"id"'* ]]
  [[ "$output" == *'"transcript"'* ]]
}
