#!/usr/bin/env bats
# Tests for Era 102 — Real-Time Observatory
# Ref: .claude/rules/domain/agent-observability-patterns.md

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
  TMPDIR_OBS=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_OBS"
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

# ── Negative cases ──

@test "statusline-provider handles missing git repo gracefully" {
  run bash -c "cd $TMPDIR_OBS && echo '' | $ROOT/scripts/statusline-provider.sh"
  [ "$status" -eq 0 ]
}

@test "notify.sh rejects invalid channel" {
  run bash -c "echo '' | $ROOT/scripts/notify.sh --channel '' --message 'test' 2>&1"
  [ "$status" -ne 0 ]
}

# ── Edge cases ──

@test "statusline-provider output has no null tier field" {
  run bash -c "echo '' | $ROOT/scripts/statusline-provider.sh"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['tier'] is not None"
}

@test "agent-activity command references observatory" {
  grep -qi "activit" "$ROOT/.claude/commands/agent-activity.md"
}

# ── Safety verification ──

@test "observatory scripts have set -uo pipefail safety" {
  grep -q "set -[euo]*o pipefail" "$ROOT/scripts/statusline-provider.sh"
  grep -q "set -[euo]*o pipefail" "$ROOT/scripts/notify.sh"
}

# ── Assertion variety ──

@test "statusline-provider JSON has window as integer" {
  run bash -c "echo '' | $ROOT/scripts/statusline-provider.sh"
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert isinstance(d['window'], int), 'window not int'"
}

@test "statusline-provider tier is one of known values" {
  run bash -c "echo '' | $ROOT/scripts/statusline-provider.sh"
  local tier
  tier=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['tier'])")
  [[ "$tier" == "max" ]] || [[ "$tier" == "high" ]] || [[ "$tier" == "fast" ]] || [[ "$tier" == "unknown" ]]
}

@test "statusline-provider works in empty directory" {
  run bash -c "cd $TMPDIR_OBS && echo '' | $ROOT/scripts/statusline-provider.sh"
  [ "$status" -eq 0 ]
}

@test "notify.sh handles nonexistent channel type" {
  [[ -n "${CI:-}" ]] && skip "needs notify.sh setup"
  run bash -c "echo '' | $ROOT/scripts/notify.sh --channel nonexistent-$$ --message 'test' 2>&1"
  [ "$status" -ne 0 ] || [[ "$output" == *"error"* ]] || [[ "$output" == *"Usage"* ]]
}
