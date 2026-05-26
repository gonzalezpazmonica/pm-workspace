#!/usr/bin/env bats
# tests/test-agent-run-logger.bats — SE-148: AgentRunSummary logger + report tests
# Ref: docs/propuestas/SE-148 spike

LOGGER="${BATS_TEST_DIRNAME}/../scripts/agent-run-logger.sh"
REPORT="${BATS_TEST_DIRNAME}/../scripts/agent-run-report.sh"

setup() {
  TMP_DIR="$(mktemp -d)"
  export TMP_DIR
  export AGENT_ACTUALS_LOG="$TMP_DIR/agent-actuals.jsonl"
  export SAVIA_WORKSPACE_DIR="$TMP_DIR"
  # Create empty log so scripts don't fail on missing file
  touch "$AGENT_ACTUALS_LOG"
}

teardown() {
  [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}

# ── Test 1: start creates a JSONL entry ─────────────────────────────────────
@test "start: generates a JSONL entry in the log" {
  run bash "$LOGGER" start "test-agent" "spike test task"
  [ "$status" -eq 0 ]
  # Output is the run_id
  [ -n "$output" ]
  RUN_ID="$output"
  # The log must contain an entry for this run_id
  grep -qF "\"run_id\":\"$RUN_ID\"" "$AGENT_ACTUALS_LOG"
}

@test "start: entry has schema_version 2 and run_status running" {
  run bash "$LOGGER" start "test-agent" "spike test task"
  [ "$status" -eq 0 ]
  RUN_ID="$output"
  RECORD="$(grep -F "\"run_id\":\"$RUN_ID\"" "$AGENT_ACTUALS_LOG")"
  echo "$RECORD" | jq -e '.schema_version == "2"'
  echo "$RECORD" | jq -e '.run_status == "running"'
  echo "$RECORD" | jq -e '.agent == "test-agent"'
}

# ── Test 2: tool-call updates the existing record ───────────────────────────
@test "tool-call: updates tools_invoked and tool_status on existing record" {
  RUN_ID="$(bash "$LOGGER" start "test-agent" "spike test task")"
  run bash "$LOGGER" tool-call "$RUN_ID" bash ok
  [ "$status" -eq 0 ]
  run bash "$LOGGER" tool-call "$RUN_ID" bash error
  [ "$status" -eq 0 ]
  run bash "$LOGGER" tool-call "$RUN_ID" read ok
  [ "$status" -eq 0 ]

  RECORD="$(grep -F "\"run_id\":\"$RUN_ID\"" "$AGENT_ACTUALS_LOG" | tail -1)"
  # tools_invoked.bash should be 2
  echo "$RECORD" | jq -e '.tools_invoked.bash == 2'
  # tool_status.bash.ok = 1, tool_status.bash.error = 1
  echo "$RECORD" | jq -e '.tool_status.bash.ok == 1'
  echo "$RECORD" | jq -e '.tool_status.bash.error == 1'
  # tools_invoked.read = 1
  echo "$RECORD" | jq -e '.tools_invoked.read == 1'
}

@test "tool-call: rejects invalid status" {
  RUN_ID="$(bash "$LOGGER" start "test-agent" "spike test task")"
  run bash "$LOGGER" tool-call "$RUN_ID" bash "INVALID_STATUS"
  [ "$status" -ne 0 ]
}

@test "tool-call: fails when run_id does not exist" {
  run bash "$LOGGER" tool-call "nonexistent-run-id-00000" bash ok
  [ "$status" -ne 0 ]
}

# ── Test 3: finish marks run_status ─────────────────────────────────────────
@test "finish: sets run_status to completed and computes duration_s" {
  RUN_ID="$(bash "$LOGGER" start "test-agent" "spike test task")"
  sleep 1
  run bash "$LOGGER" finish "$RUN_ID" completed
  [ "$status" -eq 0 ]

  RECORD="$(grep -F "\"run_id\":\"$RUN_ID\"" "$AGENT_ACTUALS_LOG" | tail -1)"
  echo "$RECORD" | jq -e '.run_status == "completed"'
  echo "$RECORD" | jq -e '.finished_at != null'
  echo "$RECORD" | jq -e '.duration_s != null and .duration_s >= 0'
}

@test "finish: tools_unused computed from tools_available minus tools_invoked" {
  RUN_ID="$(bash "$LOGGER" start "test-agent" "spike test task")"
  # Annotate available tools
  bash "$LOGGER" annotate "$RUN_ID" --tools-available "bash,read,write,glob"
  # Invoke only bash and read
  bash "$LOGGER" tool-call "$RUN_ID" bash ok
  bash "$LOGGER" tool-call "$RUN_ID" read ok
  bash "$LOGGER" finish "$RUN_ID" completed

  RECORD="$(grep -F "\"run_id\":\"$RUN_ID\"" "$AGENT_ACTUALS_LOG" | tail -1)"
  # tools_unused should contain write and glob
  echo "$RECORD" | jq -e '(.tools_unused | sort) == ["glob","write"]'
}

@test "finish: rejects invalid run_status" {
  RUN_ID="$(bash "$LOGGER" start "test-agent" "spike test task")"
  run bash "$LOGGER" finish "$RUN_ID" "bad-status"
  [ "$status" -ne 0 ]
}

# ── Test 4: report does not fail with empty log ──────────────────────────────
@test "report: does not fail with empty JSONL file" {
  : > "$AGENT_ACTUALS_LOG"
  run bash "$REPORT" summary
  [ "$status" -eq 0 ]
}

@test "report: shows summary row for completed runs" {
  RUN_ID="$(bash "$LOGGER" start "test-agent" "spike test task")"
  bash "$LOGGER" tool-call "$RUN_ID" bash ok
  bash "$LOGGER" finish "$RUN_ID" completed

  run bash "$REPORT" summary
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "test-agent"
}

@test "report --unused-tools: lists tools not invoked" {
  RUN_ID="$(bash "$LOGGER" start "test-agent" "spike test task")"
  bash "$LOGGER" annotate "$RUN_ID" --tools-available "bash,read,glob"
  bash "$LOGGER" tool-call "$RUN_ID" bash ok
  bash "$LOGGER" finish "$RUN_ID" completed

  run bash "$REPORT" --unused-tools
  [ "$status" -eq 0 ]
  # glob and read were declared but not invoked (read was not tool-called)
  echo "$output" | grep -q "test-agent"
}

@test "report --error-prone: lists tools with >20% error rate" {
  RUN_ID="$(bash "$LOGGER" start "error-agent" "error test")"
  bash "$LOGGER" tool-call "$RUN_ID" bash ok
  bash "$LOGGER" tool-call "$RUN_ID" bash error
  bash "$LOGGER" tool-call "$RUN_ID" bash error
  bash "$LOGGER" tool-call "$RUN_ID" bash error
  # bash: 1 ok, 3 error → 75% error rate
  bash "$LOGGER" finish "$RUN_ID" completed

  run bash "$REPORT" --error-prone
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "bash"
}

# ── Test 5: backward compatibility ──────────────────────────────────────────
@test "backward-compat: legacy spec-estimation records coexist without breaking report" {
  # Write a legacy (schema v1 / no schema_version) record to the log
  echo '{"spec_id":"SE-001","category":"standard","human_estimate_days":3,"agent_estimate_hours_predicted":3.0,"agent_wallclock_hours_actual":2.0,"verdict":"shipped","completed_at":"2026-04-10T12:00:00Z"}' \
    >> "$AGENT_ACTUALS_LOG"

  # Add one SE-148 record
  RUN_ID="$(bash "$LOGGER" start "compat-agent" "compat test")"
  bash "$LOGGER" finish "$RUN_ID" completed

  # Report must succeed and show the SE-148 agent (not crash on the legacy record)
  run bash "$REPORT" summary
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "compat-agent"
}

@test "backward-compat: start does not modify legacy records in log" {
  # Seed legacy record
  LEGACY='{"spec_id":"LEGACY-001","verdict":"shipped"}'
  echo "$LEGACY" >> "$AGENT_ACTUALS_LOG"

  bash "$LOGGER" start "new-agent" "task"

  # Legacy line must still be present verbatim
  grep -qF '"spec_id":"LEGACY-001"' "$AGENT_ACTUALS_LOG"
}

@test "annotate: token and cost fields are stored correctly" {
  RUN_ID="$(bash "$LOGGER" start "cost-agent" "cost test")"
  bash "$LOGGER" annotate "$RUN_ID" \
    --tokens-in 1000 --tokens-out 500 --cost-usd 0.0042 \
    --model "claude-sonnet-4-6"
  bash "$LOGGER" finish "$RUN_ID" completed

  RECORD="$(grep -F "\"run_id\":\"$RUN_ID\"" "$AGENT_ACTUALS_LOG" | tail -1)"
  echo "$RECORD" | jq -e '.tokens_in == 1000'
  echo "$RECORD" | jq -e '.tokens_out == 500'
  echo "$RECORD" | jq -e '.cost_usd == 0.0042'
  echo "$RECORD" | jq -e '.models_used | contains(["claude-sonnet-4-6"])'
}
