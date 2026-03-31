#!/usr/bin/env bats
# Tests for SPEC-044 trace-pattern-extractor

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  SCRIPT="scripts/trace-pattern-extractor.sh"
  TMPDIR=$(mktemp -d)
  # Generate 25 traces: 20 success + 5 failure for agent-a
  for i in $(seq 1 20); do
    echo '{"agent":"agent-a","outcome":"success","tokens_in":1000,"tokens_out":50,"duration_ms":5000,"budget_exceeded":false,"token_budget":8000}' >> "$TMPDIR/traces.jsonl"
  done
  for i in $(seq 1 5); do
    echo '{"agent":"agent-a","outcome":"failure","tokens_in":1000,"tokens_out":50,"duration_ms":5000,"budget_exceeded":true,"token_budget":8000}' >> "$TMPDIR/traces.jsonl"
  done
  # 10 traces for agent-b (below min threshold of 20)
  for i in $(seq 1 10); do
    echo '{"agent":"agent-b","outcome":"success","tokens_in":500,"tokens_out":25,"duration_ms":3000,"budget_exceeded":false,"token_budget":4000}' >> "$TMPDIR/traces.jsonl"
  done
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "trace-pattern-extractor.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "trace-pattern-extractor.sh has set -uo pipefail" {
  head -5 "$SCRIPT" | grep -q "set -[euo]*o pipefail"
}

@test "analyzes traces and produces JSON" {
  run bash "$SCRIPT" --traces-file "$TMPDIR/traces.jsonl"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)"
}

@test "detects agent-a as candidate (25 traces >= 20 min)" {
  run bash "$SCRIPT" --traces-file "$TMPDIR/traces.jsonl"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['analyzed'] >= 1, f'Expected >=1 analyzed, got {d[\"analyzed\"]}'
assert d['candidates'][0]['agent'] == 'agent-a'
"
}

@test "agent-b excluded (10 traces < 20 min)" {
  run bash "$SCRIPT" --traces-file "$TMPDIR/traces.jsonl"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
agents = [c['agent'] for c in d['candidates']]
assert 'agent-b' not in agents, 'agent-b should be excluded (below min)'
"
}

@test "computes failure rate correctly" {
  run bash "$SCRIPT" --traces-file "$TMPDIR/traces.jsonl"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
a = d['candidates'][0]
assert a['failure_rate'] == 0.2, f'Expected 0.2, got {a[\"failure_rate\"]}'
"
}

@test "computes budget overage rate correctly" {
  run bash "$SCRIPT" --traces-file "$TMPDIR/traces.jsonl"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
a = d['candidates'][0]
assert a['budget_overage_rate'] == 0.2, f'Expected 0.2, got {a[\"budget_overage_rate\"]}'
"
}

@test "detects frequent_failures pattern at > 20%" {
  # Add more failures to push over 20%
  for i in $(seq 1 10); do
    echo '{"agent":"agent-c","outcome":"failure","tokens_in":1000,"tokens_out":50,"duration_ms":5000,"budget_exceeded":false,"token_budget":8000}' >> "$TMPDIR/traces.jsonl"
  done
  for i in $(seq 1 15); do
    echo '{"agent":"agent-c","outcome":"success","tokens_in":1000,"tokens_out":50,"duration_ms":5000,"budget_exceeded":false,"token_budget":8000}' >> "$TMPDIR/traces.jsonl"
  done
  run bash "$SCRIPT" --traces-file "$TMPDIR/traces.jsonl" --agent agent-c
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
patterns = [p['id'] for p in d['candidates'][0]['patterns']]
assert 'frequent_failures' in patterns, f'Expected frequent_failures, got {patterns}'
"
}

@test "handles missing traces file gracefully" {
  run bash "$SCRIPT" --traces-file "/nonexistent/traces.jsonl"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "handles empty traces file" {
  touch "$TMPDIR/empty.jsonl"
  run bash "$SCRIPT" --traces-file "$TMPDIR/empty.jsonl"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['analyzed'] == 0
"
}

@test "respects --min-traces parameter" {
  run bash "$SCRIPT" --traces-file "$TMPDIR/traces.jsonl" --min-traces 5
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
# agent-b has 10 traces, should pass with min=5
agents = [c['agent'] for c in d['candidates']]
assert 'agent-b' in agents, f'agent-b should be included with min=5, got {agents}'
"
}

@test "SPEC-044 document exists" {
  [ -f "docs/propuestas/SPEC-044-trace-prompt-optimization.md" ]
}

@test "trace-optimize command exists" {
  [ -f ".claude/commands/trace-optimize.md" ]
}
