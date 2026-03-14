#!/usr/bin/env bats
# Tests for Era 102 — Real-Time Observatory

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
}

@test "statusline-provider.sh exists and is executable" {
  [ -x "$ROOT/scripts/statusline-provider.sh" ]
}

@test "notify.sh exists and is executable" {
  [ -x "$ROOT/scripts/notify.sh" ]
}

@test "agent-activity command exists" {
  [ -f "$ROOT/.claude/commands/agent-activity.md" ]
}

@test "statusline-provider outputs valid JSON" {
  run bash -c "echo '' | $ROOT/scripts/statusline-provider.sh"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'tier' in d; assert 'window' in d"
}

@test "statusline-provider includes branch info" {
  run bash -c "echo '' | $ROOT/scripts/statusline-provider.sh"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"branch"'
}

@test "notify.sh shows usage without args" {
  run bash -c "echo '' | $ROOT/scripts/notify.sh 2>&1"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "usage"
}
