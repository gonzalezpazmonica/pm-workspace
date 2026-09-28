#!/usr/bin/env bats
# Ref: docs/specs/SE-405-harness-observability-increments.spec.md (Slice 1, AC1-AC3)
# Ledger temporal (SAVIA_RUNS_LEDGER): nunca toca data/agent-runs-ledger.jsonl.

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-$(mktemp -d)}"
  RUNS="$BATS_TEST_DIRNAME/../scripts/savia-runs.sh"
  CAPTURE_HOOK="$BATS_TEST_DIRNAME/../.claude/hooks/runs-cost-capture-hook.sh"
  export SAVIA_RUNS_LEDGER="$TMPDIR/ledger.jsonl"
  RUN_ID=$(bash "$RUNS" start overnight savia "tarea de prueba" | tail -1 | grep -oE '[0-9a-f-]{8,}' | head -1)
}

teardown() { cd /; }

@test "safety: the SubagentStop hook declares set -uo pipefail" {
  head -3 "$CAPTURE_HOOK" | grep -q "set -uo pipefail"
}

@test "AC1: cost records tokens for a run and agent" {
  run bash "$RUNS" cost "$RUN_ID" --agent test-engineer --model sonnet --tokens-in 1200 --tokens-out 300
  [ "$status" -eq 0 ]
  run bash -c "bash '$RUNS' status --json | jq -r --arg id '$RUN_ID' '.runs[] | select(.run_id==\$id) | .cost.tokens_in'"
  [ "$output" = "1200" ]
}

@test "AC2: show prints total and per-agent breakdown, accumulating calls" {
  bash "$RUNS" cost "$RUN_ID" --agent a1 --model m --tokens-in 100 --tokens-out 10 >/dev/null
  bash "$RUNS" cost "$RUN_ID" --agent a1 --model m --tokens-in 50 --tokens-out 5 >/dev/null
  bash "$RUNS" cost "$RUN_ID" --agent a2 --model m --tokens-in 1 --tokens-out 1 --usd 0.25 >/dev/null
  run bash "$RUNS" show "$RUN_ID"
  [[ "$output" == *"cost        : in=151 out=16"* ]]
  [[ "$output" == *"a1: in=150 out=15 calls=2"* ]]
  [[ "$output" == *"usd=0.25"* ]]
}

@test "AC1 reject: unknown run_id exits 2" {
  run bash "$RUNS" cost no-such-run --agent a --model m --tokens-in 1 --tokens-out 1
  [ "$status" -eq 2 ]
}

@test "AC1 invalid: negative or non-numeric tokens exit 2" {
  run bash "$RUNS" cost "$RUN_ID" --agent a --model m --tokens-in -5 --tokens-out 1
  [ "$status" -eq 2 ]
  run bash "$RUNS" cost "$RUN_ID" --agent a --model m --tokens-in abc --tokens-out 1
  [ "$status" -eq 2 ]
}

@test "AC1 empty: empty agent name exits 2" {
  run bash "$RUNS" cost "$RUN_ID" --agent "" --model m --tokens-in 1 --tokens-out 1
  [ "$status" -eq 2 ]
}

@test "AC3: capture sums usage from a subagent transcript into the run" {
  tr="$TMPDIR/transcript.jsonl"
  printf '%s\n' \
    '{"type":"assistant","message":{"model":"m1","usage":{"input_tokens":100,"output_tokens":20}}}' \
    '{"type":"user","message":{"content":"x"}}' \
    '{"type":"assistant","message":{"model":"m1","usage":{"input_tokens":30,"output_tokens":5}}}' > "$tr"
  printf '{"agent_type":"code-reviewer","agent_transcript_path":"%s"}' "$tr" \
    | SAVIA_RUN_ID="$RUN_ID" bash "$RUNS" capture-cost
  run bash "$RUNS" show "$RUN_ID"
  [[ "$output" == *"code-reviewer: in=130 out=25 calls=1"* ]]
}

@test "boundary: capture without SAVIA_RUN_ID does nothing and exits 0" {
  run bash -c "echo '{}' | env -u SAVIA_RUN_ID bash '$RUNS' capture-cost"
  [ "$status" -eq 0 ]
  run bash "$RUNS" show "$RUN_ID"
  [[ "$output" == *"cost        : (none)"* ]]
}

@test "missing: capture with a nonexistent transcript exits 0 without recording" {
  printf '{"agent_type":"x","agent_transcript_path":"%s"}' "$TMPDIR/nope.jsonl" \
    | SAVIA_RUN_ID="$RUN_ID" bash "$RUNS" capture-cost
  run bash "$RUNS" show "$RUN_ID"
  [[ "$output" == *"cost        : (none)"* ]]
}

@test "hook: the SubagentStop hook records cost end to end through savia-runs capture-cost" {
  tr="$TMPDIR/t2.jsonl"
  printf '%s\n' '{"type":"assistant","message":{"model":"m2","usage":{"input_tokens":7,"output_tokens":3}}}' > "$tr"
  printf '{"agent_type":"architect","agent_transcript_path":"%s"}' "$tr" \
    | SAVIA_RUN_ID="$RUN_ID" CLAUDE_PROJECT_DIR="$BATS_TEST_DIRNAME/.." bash "$CAPTURE_HOOK"
  run bash "$RUNS" show "$RUN_ID"
  [[ "$output" == *"architect: in=7 out=3 calls=1"* ]]
}
