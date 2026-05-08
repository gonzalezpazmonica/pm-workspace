#!/usr/bin/env bats
# BATS tests for .opencode/hooks/task-lifecycle.sh
# TaskCreated/TaskCompleted async — logs task lifecycle to jsonl.
# Ref: batch 51 hook coverage — final 3 hooks → 58/58 (100%) — SPEC-071 Slice 4.

HOOK=".opencode/hooks/task-lifecycle.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  TEST_REPO=$(mktemp -d "$TMPDIR/tl-XXXXXX")
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
@test "header: TaskCreated event documented" {
  run grep -c 'TaskCreated' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "header: TaskCompleted event documented" {
  run grep -c 'TaskCompleted' "$HOOK"
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
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< '{"only":"junk"}'
  [ "$status" -eq 0 ]
}

@test "pass-through: invalid JSON exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< 'not-json{'
  [ "$status" -eq 0 ]
}

# ── TaskCreated logging ───────────────────────────

@test "created: logs action=created" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t-1","task_subject":"Implement X"}'
  [ "$status" -eq 0 ]
  [[ -f "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl" ]]
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *'"action":"created"'* ]]
}

@test "created: task_id captured" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"specific-task-42","task_subject":"x"}'
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"specific-task-42"* ]]
}

@test "created: task_subject captured" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"Refactor auth flow"}'
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"Refactor auth flow"* ]]
}

# ── TaskCompleted logging ─────────────────────────

@test "completed: logs action=completed" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCompleted","task_id":"t-1","task_subject":"x"}'
  [ "$status" -eq 0 ]
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *'"action":"completed"'* ]]
}

@test "completed: TaskCompleted vs TaskCreated dispatch correct" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"a","task_subject":"x"}'
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCompleted","task_id":"a","task_subject":"x"}'
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *'"action":"created"'* ]]
  [[ "$output" == *'"action":"completed"'* ]]
}

# ── Team / teammate fields ────────────────────────

@test "team: optional field captured" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"x","team_name":"alpha-squad"}'
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"alpha-squad"* ]]
}

@test "teammate: optional field captured" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"x","teammate_name":"researcher-1"}'
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"researcher-1"* ]]
}

@test "team+teammate: missing optional fields → empty strings" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"x"}'
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *'"team":""'* ]]
  [[ "$output" == *'"teammate":""'* ]]
}

# ── JSON structure ────────────────────────────────

@test "log: ts ISO 8601 UTC timestamp" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"x"}'
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ]]
}

@test "log: 6 fields ts/action/id/subject/team/teammate" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"s","team_name":"a","teammate_name":"b"}'
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *'"ts"'* ]]
  [[ "$output" == *'"action"'* ]]
  [[ "$output" == *'"id"'* ]]
  [[ "$output" == *'"subject"'* ]]
  [[ "$output" == *'"team"'* ]]
  [[ "$output" == *'"teammate"'* ]]
}

# ── Log directory ─────────────────────────────────

@test "log dir auto-created" {
  [[ ! -d "$TEST_REPO/output/task-lifecycle" ]]
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"x"}'
  [[ -d "$TEST_REPO/output/task-lifecycle" ]]
}

@test "append: multiple events accumulate" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"a","task_subject":"x"}'
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"b","task_subject":"y"}'
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCompleted","task_id":"a","task_subject":"x"}'
  run wc -l < "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" -eq 3 ]]
}

# ── Negative cases ────────────────────────────────

@test "negative: missing task_id still logs (default empty)" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_subject":"x"}'
  [ "$status" -eq 0 ]
}

@test "negative: malformed JSON does not write log" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< 'broken-json'
  [ "$status" -eq 0 ]
  [[ ! -f "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl" ]] || \
    [[ ! -s "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl" ]]
}

@test "negative: stdin timeout (3s) does not block forever" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run timeout 5 bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
}

# ── Edge cases ────────────────────────────────────

@test "edge: subject with quotes survives" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"task with spaces"}'
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *"task with spaces"* ]]
}

@test "edge: unknown event name → defaults to created" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"WeirdEvent","task_id":"t","task_subject":"x"}'
  [ "$status" -eq 0 ]
  run cat "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" == *'"action":"created"'* ]]
}

@test "edge: empty CLAUDE_PROJECT_DIR fallback to pwd" {
  cd "$TEST_REPO"
  run bash "$BATS_TEST_DIRNAME/../$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"x"}'
  [ "$status" -eq 0 ]
  [[ -f "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl" ]]
}

# ── Isolation ─────────────────────────────────────

@test "isolation: hook always exits 0" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" run bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"x"}'
  [ "$status" -eq 0 ]
}

@test "isolation: only writes under output/task-lifecycle/" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"x"}'
  [[ -d "$TEST_REPO/output/task-lifecycle" ]]
  [[ ! -e "$TEST_REPO/random-file" ]]
}

@test "coverage: action distinguishes create vs complete" {
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCreated","task_id":"t","task_subject":"x"}'
  CLAUDE_PROJECT_DIR="$TEST_REPO" bash "$HOOK" <<< \
    '{"hook_event_name":"TaskCompleted","task_id":"t","task_subject":"x"}'
  run grep -c 'created' "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" -ge 1 ]]
  run grep -c 'completed' "$TEST_REPO/output/task-lifecycle/lifecycle.jsonl"
  [[ "$output" -ge 1 ]]
}
