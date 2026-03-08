#!/usr/bin/env bats

setup() {
  SCRIPT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)/scripts/agent-activity.sh"
  export TEST_TMPDIR="/tmp/agentact-$$-$BATS_TEST_NUMBER"
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
  mkdir -p "$TEST_TMPDIR/.pm-workspace"
}

teardown() {
  rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

@test "script exists and is executable-ready" {
  [ -f "$SCRIPT" ]
}

@test "handles missing trace file gracefully" {
  run bash -c "HOME='$TEST_TMPDIR' bash '$SCRIPT' --summary"
  [ "$status" -eq 0 ]
}

@test "summary mode shows dashboard header" {
  echo '{"timestamp":"2026-03-08T10:00:00Z","agent":"sprint-manager","outcome":"success","duration_ms":1200}' > "$TEST_TMPDIR/.pm-workspace/agent-trace.jsonl"
  echo '{"timestamp":"2026-03-08T10:01:00Z","agent":"code-runner","outcome":"success","duration_ms":800}' >> "$TEST_TMPDIR/.pm-workspace/agent-trace.jsonl"
  run bash -c "HOME='$TEST_TMPDIR' bash '$SCRIPT' --summary"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Agent Activity Dashboard" ]]
}

@test "json mode outputs valid JSON" {
  echo '{"timestamp":"2026-03-08T10:00:00Z","agent":"sprint-manager","outcome":"success","duration_ms":1200}' > "$TEST_TMPDIR/.pm-workspace/agent-trace.jsonl"
  run bash -c "HOME='$TEST_TMPDIR' bash '$SCRIPT' --json | jq '.' > /dev/null 2>&1"
  [ "$status" -eq 0 ]
}

@test "recent mode shows last N entries" {
  for i in {1..5}; do
    echo "{\"timestamp\":\"2026-03-08T10:0$i:00Z\",\"agent\":\"agent-$i\",\"outcome\":\"success\",\"duration_ms\":100}" >> "$TEST_TMPDIR/.pm-workspace/agent-trace.jsonl"
  done
  run bash -c "HOME='$TEST_TMPDIR' bash '$SCRIPT' --recent 2 | wc -l"
  [ "$status" -eq 0 ]
  [ "$output" -eq 2 ]
}

@test "handles empty trace file" {
  touch "$TEST_TMPDIR/.pm-workspace/agent-trace.jsonl"
  run bash -c "HOME='$TEST_TMPDIR' bash '$SCRIPT' --summary"
  [ "$status" -eq 0 ]
}
