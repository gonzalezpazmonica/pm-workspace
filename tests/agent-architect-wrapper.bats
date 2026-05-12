#!/usr/bin/env bats
# Tests for scripts/agent-architect.sh — SPEC-AGENT-ARCHITECT §4

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WRAPPER="$ROOT/scripts/agent-architect.sh"
}

@test "wrapper exists and is executable" {
  [ -x "$WRAPPER" ]
}

@test "wrapper supports --help" {
  run "$WRAPPER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent"* ]]
}

@test "wrapper analyses a single real agent without crashing" {
  run "$WRAPPER" --agent dotnet-developer
  [ "$status" -eq 0 ]
  [[ "$output" == *"length"* ]]
  [[ "$output" == *"tools"* ]]
}

@test "wrapper --all completes for whole catalog" {
  run timeout 60 "$WRAPPER" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"Agent Architect"* ]] || [[ "$output" == *"agent"* ]]
}

@test "wrapper --json emits valid JSON for single agent" {
  run "$WRAPPER" --agent dotnet-developer --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; json.loads(sys.stdin.read())"
}

@test "wrapper rejects nonexistent agent gracefully" {
  run "$WRAPPER" --agent nonexistent-agent-xyz
  # Either non-zero exit or a clear error message — must not silent-pass.
  if [ "$status" -eq 0 ]; then
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"error"* ]] || [[ "$output" == *"Error"* ]]
  fi
}
