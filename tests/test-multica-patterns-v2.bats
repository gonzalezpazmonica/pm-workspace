#!/usr/bin/env bats
# tests/test-multica-patterns-v2.bats
# BATS tests for Multica v2 patterns:
#   1) Monotonic seq numbers in session-event-log (catch-up queries)
#   2) Session resumption index (agent_type, spec_id) → last_session_id
# Source: Multica (github.com/multica-ai/multica) daemon.go task_message table

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export EVENT_SCRIPT="$REPO_ROOT/scripts/session-event-log.sh"
  export RESUME_SCRIPT="$REPO_ROOT/scripts/session-resume-index.sh"
  TMPDIR_TEST=$(mktemp -d)
  export SESSION_LOG_DIR="$TMPDIR_TEST/events"
  export SESSION_RESUME_INDEX="$TMPDIR_TEST/resume-index.tsv"
  export SAVIA_SESSION_ID="bats-session-$$"
}
teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── Pattern 1: seq numbers in session-event-log ───────────────────────────

@test "emit adds monotonic seq starting at 1" {
  run bash "$EVENT_SCRIPT" emit decision "alpha"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"seq=1"* ]]
}

@test "emit increments seq per event" {
  bash "$EVENT_SCRIPT" emit decision "one" >/dev/null
  bash "$EVENT_SCRIPT" emit note "two" >/dev/null
  run bash "$EVENT_SCRIPT" emit error "three"
  [[ "$output" == *"seq=3"* ]]
}

@test "emitted JSONL contains seq field" {
  bash "$EVENT_SCRIPT" emit decision "test" >/dev/null
  local logfile
  logfile=$(ls "$SESSION_LOG_DIR"/*.jsonl | head -1)
  grep -q '"seq":1' "$logfile"
}

@test "query --since-seq filters events with seq > N" {
  for i in 1 2 3 4 5; do
    bash "$EVENT_SCRIPT" emit note "event-$i" >/dev/null
  done
  run bash "$EVENT_SCRIPT" query --since-seq 2
  # Should include seq 3, 4, 5 but not 1, 2
  [[ "$output" == *"event-3"* ]]
  [[ "$output" == *"event-4"* ]]
  [[ "$output" == *"event-5"* ]]
  [[ "$output" != *"event-1"* ]]
  [[ "$output" != *"event-2"* ]]
}

@test "query --since-seq 0 returns all events" {
  bash "$EVENT_SCRIPT" emit note "alpha" >/dev/null
  bash "$EVENT_SCRIPT" emit note "beta" >/dev/null
  run bash "$EVENT_SCRIPT" query --since-seq 0
  [[ "$output" == *"alpha"* ]]
  [[ "$output" == *"beta"* ]]
}

@test "query --session scopes to specific session file" {
  bash "$EVENT_SCRIPT" emit note "session-a-event" >/dev/null
  SAVIA_SESSION_ID="other-session" bash "$EVENT_SCRIPT" emit note "session-b-event" >/dev/null
  run bash "$EVENT_SCRIPT" query --session "$SAVIA_SESSION_ID"
  [[ "$output" == *"session-a-event"* ]]
  [[ "$output" != *"session-b-event"* ]]
}

@test "query --session fails for nonexistent session" {
  bash "$EVENT_SCRIPT" emit note "test" >/dev/null
  run bash "$EVENT_SCRIPT" query --session "nonexistent-id"
  [[ "$status" -ne 0 ]]
}

@test "seq numbers combine with --type filter" {
  bash "$EVENT_SCRIPT" emit decision "d1" >/dev/null
  bash "$EVENT_SCRIPT" emit note "n1" >/dev/null
  bash "$EVENT_SCRIPT" emit decision "d2" >/dev/null
  run bash "$EVENT_SCRIPT" query --type decision --since-seq 1
  [[ "$output" == *"d2"* ]]
  [[ "$output" != *"d1"* ]]
  [[ "$output" != *"n1"* ]]
}

# ── Pattern 2: session-resume-index ────────────────────────────────────────

@test "session-resume-index.sh exists and is executable" {
  [[ -x "$RESUME_SCRIPT" ]]
}

@test "status runs on empty index" {
  run bash "$RESUME_SCRIPT" status
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Session Resume Index"* ]]
}

@test "record stores (agent, spec) → session mapping" {
  run bash "$RESUME_SCRIPT" record "dotnet-developer" "SE-015" "sess-123"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OK"* ]]
}

@test "lookup retrieves recorded session" {
  bash "$RESUME_SCRIPT" record "dotnet-developer" "SE-015" "sess-123" "/tmp/work" >/dev/null
  run bash "$RESUME_SCRIPT" lookup "dotnet-developer" "SE-015"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"session_id=sess-123"* ]]
  [[ "$output" == *"work_dir=/tmp/work"* ]]
}

@test "lookup fails for unknown (agent, spec)" {
  run bash "$RESUME_SCRIPT" lookup "nonexistent-agent" "SE-999"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"NOT_FOUND"* ]]
}

@test "record overwrites previous session for same (agent, spec)" {
  bash "$RESUME_SCRIPT" record "dotnet-developer" "SE-015" "sess-old" >/dev/null
  bash "$RESUME_SCRIPT" record "dotnet-developer" "SE-015" "sess-new" >/dev/null
  run bash "$RESUME_SCRIPT" lookup "dotnet-developer" "SE-015"
  [[ "$output" == *"sess-new"* ]]
  [[ "$output" != *"sess-old"* ]]
}

@test "list shows all entries" {
  bash "$RESUME_SCRIPT" record "agent-a" "SPEC-1" "s1" >/dev/null
  bash "$RESUME_SCRIPT" record "agent-b" "SPEC-2" "s2" >/dev/null
  run bash "$RESUME_SCRIPT" list
  [[ "$output" == *"agent-a"* ]]
  [[ "$output" == *"agent-b"* ]]
  [[ "$output" == *"SPEC-1"* ]]
  [[ "$output" == *"SPEC-2"* ]]
}

@test "list --agent filters by agent_type" {
  bash "$RESUME_SCRIPT" record "agent-a" "SPEC-1" "s1" >/dev/null
  bash "$RESUME_SCRIPT" record "agent-b" "SPEC-2" "s2" >/dev/null
  run bash "$RESUME_SCRIPT" list --agent "agent-a"
  [[ "$output" == *"agent-a"* ]]
  [[ "$output" != *"agent-b"* ]]
}

@test "forget removes entry" {
  bash "$RESUME_SCRIPT" record "agent-a" "SPEC-1" "s1" >/dev/null
  run bash "$RESUME_SCRIPT" forget "agent-a" "SPEC-1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"OK"* ]]
  run bash "$RESUME_SCRIPT" lookup "agent-a" "SPEC-1"
  [[ "$status" -ne 0 ]]
}

@test "forget fails for nonexistent entry" {
  run bash "$RESUME_SCRIPT" forget "nonexistent" "SPEC-X"
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"NOT_FOUND"* ]]
}

@test "record requires all arguments" {
  run bash "$RESUME_SCRIPT" record "agent-a" "SPEC-1"
  [[ "$status" -ne 0 ]]
}

# ── Integration ────────────────────────────────────────────────────────────

@test "both patterns work independently in same session" {
  bash "$EVENT_SCRIPT" emit decision "task-start" >/dev/null
  bash "$RESUME_SCRIPT" record "dotnet-developer" "SE-015" "$SAVIA_SESSION_ID" >/dev/null

  run bash "$RESUME_SCRIPT" lookup "dotnet-developer" "SE-015"
  [[ "$output" == *"session_id=$SAVIA_SESSION_ID"* ]]

  run bash "$EVENT_SCRIPT" query --session "$SAVIA_SESSION_ID"
  [[ "$output" == *"task-start"* ]]
}
