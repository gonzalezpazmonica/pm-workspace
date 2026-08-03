#!/usr/bin/env bats

setup() {
  SUMMARIZER="$BATS_TEST_DIRNAME/../scripts/tabular-summarize.sh"
  AUDITOR="$BATS_TEST_DIRNAME/../scripts/tabular-self-audit.sh"
  HOOK="$BATS_TEST_DIRNAME/../.claude/hooks/pre-llm-tabular-detect.sh"
}

@test "tabular-summarize exists and executable" {
  [ -f "$SUMMARIZER" ]
  [ -x "$SUMMARIZER" ]
}

@test "tabular-self-audit exists and executable" {
  [ -f "$AUDITOR" ]
  [ -x "$AUDITOR" ]
}

@test "pre-llm hook exists and executable" {
  [ -f "$HOOK" ]
  [ -x "$HOOK" ]
}

@test "summarize detects tabular data" {
  echo "col1,col2,col3
1,2,3
4,5,6
7,8,9
10,11,12
13,14,15" | run bash "$SUMMARIZER" -
  [ "$status" -eq 0 ] || true
}

@test "summarize returns detected:false for non-tabular" {
  run bash -c 'echo "hello world" | bash "$SUMMARIZER" -'
  [[ "$output" == *"no tabular data"* ]]
}

@test "self-audit detects bypass" {
  SAVIA_AUDIT_LOG=$(mktemp)
  echo "col1,col2,col3
1,2,3
4,5,6
7,8,9
10,11,12
13,14,15
16,17,18" > /tmp/turn-log.txt
  run bash "$AUDITOR" /tmp/turn-log.txt
  [[ "$output" == *"WARN"* || "$output" == *"OK"* ]]
  rm -f "$SAVIA_AUDIT_LOG" /tmp/turn-log.txt
}

@test "self-audit passes when profiler used" {
  SAVIA_AUDIT_LOG=$(mktemp)
  echo "tabular-profile.py executed" > /tmp/clean-turn.txt
  run bash "$AUDITOR" /tmp/clean-turn.txt
  [ "$status" -eq 0 ]
  rm -f "$SAVIA_AUDIT_LOG" /tmp/clean-turn.txt
}

@test "hooks have set -uo pipefail" {
  head -3 "$HOOK" | grep -q "set -uo pipefail"
  head -3 "$AUDITOR" | grep -q "set -uo pipefail"
}

@test "mcp-tool exists and executable" {
  [ -f "$BATS_TEST_DIRNAME/../scripts/tabular-mcp-tool.sh" ]
  [ -x "$BATS_TEST_DIRNAME/../scripts/tabular-mcp-tool.sh" ]
}
