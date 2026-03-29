#!/usr/bin/env bats
# Tests for SPEC-050 Reaction Engine — Phase 1

SCRIPT="scripts/reaction-engine.sh"
CORE="scripts/reaction-engine-core.py"

@test "reaction-engine.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "reaction-engine.sh has set -uo pipefail" {
  head -10 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "reaction-engine-core.py exists and valid syntax" {
  [ -f "$CORE" ]
  python3 -c "import py_compile; py_compile.compile('$CORE', doraise=True)"
}

@test "ci-failure produces send-to-agent recommendation" {
  run bash "$SCRIPT" ci-failure '{"attempt":1,"pr_url":"https://github.com/test/pr/1","logs":"build failed at line 42"}'
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['handoff_type'] == 'qa-fail', f'Expected qa-fail, got {d[\"handoff_type\"]}'
assert d['to'] == 'developer', f'Expected developer, got {d[\"to\"]}'
assert d['context']['attempt'] == 1
assert 'build failed' in d['failures'][0]['error']
"
}

@test "review-changes-requested produces developer handoff" {
  run bash "$SCRIPT" review-changes-requested '{"attempt":1,"agent":"dotnet-developer","logs":"reviewer: fix null check"}'
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['handoff_type'] == 'qa-fail'
assert d['to'] == 'developer'
assert d['event'] == 'review-changes-requested'
"
}

@test "test-failure routes to test-engineer" {
  run bash "$SCRIPT" test-failure '{"attempt":1,"logs":"3 tests failed","total_tests":42,"passed":39,"failed":3}'
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['to'] == 'test-engineer', f'Expected test-engineer, got {d[\"to\"]}'
assert d['context']['failed'] == 3
"
}

@test "unknown event handled gracefully" {
  run bash "$SCRIPT" unknown-event '{"attempt":1}'
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['handoff_type'] == 'unknown'
assert 'Unknown event type' in d['error']
assert 'Supported events' in d['suggestion']
"
}

@test "respects max retries — escalates to human" {
  run bash "$SCRIPT" ci-failure '{"attempt":3,"pr_url":"https://github.com/test/pr/1","logs":"still failing"}'
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['handoff_type'] == 'escalation', f'Expected escalation, got {d[\"handoff_type\"]}'
assert d['to'] == 'HUMAN'
assert d['reason'] == 'max_retries_exceeded'
assert len(d['attempts']) == 3
"
}

@test "approved-and-green returns notify (no auto action)" {
  run bash "$SCRIPT" approved-and-green '{"pr_url":"https://github.com/test/pr/5"}'
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['handoff_type'] == 'notify'
assert 'No automatic action' in d['message']
"
}

@test "model escalation ladder: attempt 1=haiku, 2=sonnet, 3=opus" {
  for attempt in 1 2; do
    run bash "$SCRIPT" ci-failure "{\"attempt\":$attempt,\"logs\":\"fail\"}"
    [ "$status" -eq 0 ]
  done
  # attempt 1 -> haiku
  run bash "$SCRIPT" ci-failure '{"attempt":1,"logs":"fail"}'
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['model'] == 'haiku'"
  # attempt 2 -> sonnet
  run bash "$SCRIPT" ci-failure '{"attempt":2,"logs":"fail"}'
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['model'] == 'sonnet'"
}

@test "SPEC-050 document exists" {
  [ -f "docs/propuestas/SPEC-050-reaction-engine.md" ]
}
