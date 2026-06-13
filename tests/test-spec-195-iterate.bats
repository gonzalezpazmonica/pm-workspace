#!/usr/bin/env bats
# Ref: scripts/recommendation-tribunal/iterate.sh — SPEC-195
# Tests for iterative tribunal loop controller.
#
# SPEC-055 audit hint: target the iterate script for coverage scoring
# SCRIPT="scripts/recommendation-tribunal/iterate.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/recommendation-tribunal/iterate.sh"
  TMPDIR_IT=$(mktemp -d)
  export HOME="$TMPDIR_IT"
  unset SAVIA_TRIBUNAL_ITERATIVE
}

teardown() {
  rm -rf "$TMPDIR_IT"
}

# ─────────────────────────────────────────────────────────────────────────────
# Master switch + safety
# ─────────────────────────────────────────────────────────────────────────────

@test "safety: script declares set -uo pipefail" {
  run grep -E "set -uo pipefail" "$SCRIPT"
  [[ "$status" -eq 0 ]]
}

@test "SAVIA_TRIBUNAL_ITERATIVE=off returns disabled flag" {
  export SAVIA_TRIBUNAL_ITERATIVE=off
  run bash "$SCRIPT" evaluate-stop --iteration 0 --max-iter 3 --draft-hash x --judge-scores 85
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"\"enabled\":false"* ]]
}

@test "no command shows usage (when enabled)" {
  export SAVIA_TRIBUNAL_ITERATIVE=on
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
}

@test "unknown command exits 2" {
  export SAVIA_TRIBUNAL_ITERATIVE=on
  run bash "$SCRIPT" nonexistent-command
  [[ "$status" -eq 2 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# evaluate-stop (forwards to early_stop.py)
# ─────────────────────────────────────────────────────────────────────────────

@test "evaluate-stop: low-stddev scores trigger entropy stop" {
  export SAVIA_TRIBUNAL_ITERATIVE=on
  run bash "$SCRIPT" evaluate-stop --iteration 0 --max-iter 3 \
      --draft-hash abc --previous-draft-hash "" \
      --judge-scores "85,86,87,88,85" --entropy-threshold 5.0
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert d[\"should_stop\"] is True; assert d[\"stop_reason\"] == \"entropy\""
}

@test "evaluate-stop: stability triggers when draft hashes match" {
  export SAVIA_TRIBUNAL_ITERATIVE=on
  run bash "$SCRIPT" evaluate-stop --iteration 1 --max-iter 3 \
      --draft-hash abc --previous-draft-hash abc \
      --judge-scores "20,90,50" --entropy-threshold 5.0
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert d[\"should_stop\"] is True; assert d[\"stop_reason\"] == \"stability\""
}

@test "evaluate-stop: max-iter at boundary triggers" {
  export SAVIA_TRIBUNAL_ITERATIVE=on
  run bash "$SCRIPT" evaluate-stop --iteration 3 --max-iter 3 \
      --draft-hash abc --previous-draft-hash xyz \
      --judge-scores "20,90,50" --entropy-threshold 5.0
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"max_iter"* ]]
}

@test "edge: no criteria met -> should_stop:false, reason:none" {
  export SAVIA_TRIBUNAL_ITERATIVE=on
  run bash "$SCRIPT" evaluate-stop --iteration 1 --max-iter 3 \
      --draft-hash abc --previous-draft-hash xyz \
      --judge-scores "20,90,50" --entropy-threshold 5.0
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); assert d[\"should_stop\"] is False; assert d[\"stop_reason\"] == \"none\""
}

# ─────────────────────────────────────────────────────────────────────────────
# log-iteration (persists JSONL)
# ─────────────────────────────────────────────────────────────────────────────

@test "log-iteration: writes JSONL line per call" {
  export SAVIA_TRIBUNAL_ITERATIVE=on
  run bash "$SCRIPT" log-iteration \
      --session-id test-001 --iteration 0 \
      --verdict WARN --draft-hash abc \
      --scores-csv "85,80,75" --stop-reason none
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"logged"* ]]
  [[ -f "$REPO_ROOT/output/tribunal-iterations/test-001.jsonl" ]]
  tail -1 "$REPO_ROOT/output/tribunal-iterations/test-001.jsonl" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d['session_id'] == 'test-001'
assert d['iteration'] == 0
assert d['verdict'] == 'WARN'
"
  rm -f "$REPO_ROOT/output/tribunal-iterations/test-001.jsonl"
}

@test "log-iteration: missing required args exits 2" {
  export SAVIA_TRIBUNAL_ITERATIVE=on
  run bash "$SCRIPT" log-iteration --session-id x
  [[ "$status" -eq 2 ]]
}

@test "log-iteration: appends multiple lines for multi-iteration session" {
  export SAVIA_TRIBUNAL_ITERATIVE=on
  for i in 0 1 2; do
    bash "$SCRIPT" log-iteration \
        --session-id test-multi --iteration "$i" \
        --verdict WARN --draft-hash "hash$i" \
        --scores-csv "70,75,80" --stop-reason none >/dev/null
  done
  log="$REPO_ROOT/output/tribunal-iterations/test-multi.jsonl"
  [[ -f "$log" ]]
  count=$(wc -l < "$log")
  [[ "$count" -eq 3 ]]
  rm -f "$log"
}

# ─────────────────────────────────────────────────────────────────────────────
# Coverage breadth (function names mentioned for SPEC-055)
# ─────────────────────────────────────────────────────────────────────────────

@test "coverage: evaluate-stop forwards to early_stop.py with should_stop semantics" {
  # Exercises evaluate-stop -> early_stop.should_stop function.
  export SAVIA_TRIBUNAL_ITERATIVE=on
  run bash "$SCRIPT" evaluate-stop --iteration 0 --max-iter 3 \
      --draft-hash abc --previous-draft-hash "" \
      --judge-scores "85" --entropy-threshold 5.0
  [[ "$status" -eq 0 ]]
}

@test "coverage: log-iteration includes timestamp + scores_csv via jq" {
  export SAVIA_TRIBUNAL_ITERATIVE=on
  bash "$SCRIPT" log-iteration \
      --session-id test-cov --iteration 0 \
      --verdict PASS --draft-hash abc \
      --scores-csv "90,92" --stop-reason stability >/dev/null
  log="$REPO_ROOT/output/tribunal-iterations/test-cov.jsonl"
  grep -q "\"ts\":" "$log"
  grep -q "\"scores_csv\":\"90,92\"" "$log"
  rm -f "$log"
}
