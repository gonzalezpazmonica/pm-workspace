#!/usr/bin/env bats
# Ref: SE-076 Slice 3 — scripts/lib/llm-healer.sh

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCRIPT="$ROOT_DIR/scripts/lib/llm-healer.sh"
  TMP=$(mktemp -d)
  export LLM_HEALER_STATS_FILE="$TMP/stats.jsonl"
  export PROJECT_ROOT="$TMP"
}
teardown() { rm -rf "$TMP"; }

# ── Usage ───────────────────────────────────────────────────────────────────

@test "healer: --help exits 0 and shows Usage" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]] || [[ "$output" == *"llm-healer.sh"* ]]
}

@test "healer: rejects unknown subcommand exit 2" {
  run bash "$SCRIPT" frobnicate
  [ "$status" -eq 2 ]
}

@test "healer: run requires --query" {
  run bash "$SCRIPT" run --runner "true"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--query"* ]]
}

@test "healer: run requires --runner" {
  run bash "$SCRIPT" run --query "x"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--runner"* ]]
}

@test "healer: run rejects unknown flag exit 2" {
  run bash "$SCRIPT" run --bogus value
  [ "$status" -eq 2 ]
}

# ── Happy path: runner succeeds first try ──────────────────────────────────

@test "healer: passes through successful runner output" {
  run bash "$SCRIPT" run --query "hello" --runner "cat"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello"* ]]
}

@test "healer: records healed=true on first-try success" {
  bash "$SCRIPT" run --query "hello" --runner "cat" >/dev/null
  [ -f "$LLM_HEALER_STATS_FILE" ]
  grep -q '"healed":true' "$LLM_HEALER_STATS_FILE"
  grep -q '"attempts":1' "$LLM_HEALER_STATS_FILE"
}

# ── Failure path: runner always fails ──────────────────────────────────────

@test "healer: returns exit 1 when all attempts fail" {
  LLM_HEALER_MAX_ATTEMPTS=2 LLM_HEALER_LLM_CMD="false" \
    run bash "$SCRIPT" run --query "x" --runner "false"
  [ "$status" -eq 1 ]
}

@test "healer: records healed=false after exhausting attempts" {
  LLM_HEALER_MAX_ATTEMPTS=1 LLM_HEALER_LLM_CMD="false" \
    bash "$SCRIPT" run --query "x" --runner "false" 2>/dev/null || true
  [ -f "$LLM_HEALER_STATS_FILE" ]
  grep -q '"healed":false' "$LLM_HEALER_STATS_FILE"
}

# ── Healing path: runner fails initially, succeeds after LLM correction ────

@test "healer: succeeds after one heal when LLM produces working query" {
  # Mock LLM that always returns 'cat' as the corrected query
  # The runner is sh -c so first attempt 'broken' fails, second attempt
  # uses healed input which the runner echoes back.
  LLM_HEALER_MAX_ATTEMPTS=2 LLM_HEALER_LLM_CMD="echo recovered_query" \
    run bash "$SCRIPT" run --query "broken_initial" --runner "grep -q . && cat || (echo err >&2; exit 1)"
  # The runner above always succeeds because grep finds chars on stdin.
  # Adjust: use a runner that fails on 'broken_initial' but passes on 'recovered_query'
  LLM_HEALER_MAX_ATTEMPTS=2 LLM_HEALER_LLM_CMD="echo recovered_query" \
    run bash "$SCRIPT" run --query "broken_initial" --runner "read line; case \$line in recovered_query) echo OK ;; *) echo bad >&2; exit 1 ;; esac"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "healer: records attempts=2 after one heal cycle succeeded" {
  LLM_HEALER_MAX_ATTEMPTS=2 LLM_HEALER_LLM_CMD="echo recovered" \
    bash "$SCRIPT" run --query "bad" --runner "read l; [[ \$l == recovered ]] && echo OK || (echo err >&2; exit 1)" >/dev/null 2>&1
  grep -q '"healed":true' "$LLM_HEALER_STATS_FILE"
  grep -q '"attempts":2' "$LLM_HEALER_STATS_FILE"
}

# ── Stats command ──────────────────────────────────────────────────────────

@test "healer: stats reports 'no stats yet' when stats file missing" {
  run bash "$SCRIPT" stats
  [ "$status" -eq 0 ]
  [[ "$output" == *"no stats"* ]]
}

@test "healer: stats reports counts when stats file populated" {
  bash "$SCRIPT" run --query "x" --runner "cat" >/dev/null
  bash "$SCRIPT" run --query "y" --runner "cat" >/dev/null
  run bash "$SCRIPT" stats
  [ "$status" -eq 0 ]
  [[ "$output" == *"total=2"* ]]
  [[ "$output" == *"healed=2"* ]]
}

# ── MAX_ATTEMPTS bound ─────────────────────────────────────────────────────

@test "healer: MAX_ATTEMPTS=1 means no healing retries" {
  LLM_HEALER_MAX_ATTEMPTS=1 LLM_HEALER_LLM_CMD="echo recovered" \
    run bash "$SCRIPT" run --query "x" --runner "false"
  [ "$status" -eq 1 ]
  grep -q '"attempts":1' "$LLM_HEALER_STATS_FILE"
}

@test "healer: MAX_ATTEMPTS=3 (default) attempts at most 3 times" {
  LLM_HEALER_LLM_CMD="echo nope" \
    bash "$SCRIPT" run --query "x" --runner "false" 2>/dev/null || true
  attempts=$(grep -o '"attempts":[0-9]*' "$LLM_HEALER_STATS_FILE" | tail -1 | cut -d: -f2)
  [ "$attempts" -le 3 ]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "edge: empty stderr capture doesn't crash" {
  LLM_HEALER_MAX_ATTEMPTS=1 \
    run bash "$SCRIPT" run --query "x" --runner "false"
  [ "$status" -eq 1 ]
}

@test "edge: prompt template variable substitution works" {
  # When LLM is invoked, the heal prompt should contain {error}, {original_query}, {attempt}.
  # We capture the prompt by feeding it to a runner that echoes stdin into a file.
  CAPTURE="$TMP/captured-prompt.txt"
  LLM_HEALER_MAX_ATTEMPTS=2 LLM_HEALER_LLM_CMD="tee $CAPTURE && echo healed_value" \
    bash "$SCRIPT" run --query "MY_QUERY" --runner "false" 2>/dev/null || true
  [ -f "$CAPTURE" ]
  grep -q "MY_QUERY" "$CAPTURE"
}

@test "edge: empty LLM heal output aborts loop" {
  # If LLM returns empty, healer must not loop forever.
  LLM_HEALER_MAX_ATTEMPTS=5 LLM_HEALER_LLM_CMD="true" \
    run bash "$SCRIPT" run --query "x" --runner "false"
  [ "$status" -eq 1 ]
}

# ── Static / safety / spec ref ─────────────────────────────────────────────

@test "spec ref: SE-076 Slice 3 cited in script header" {
  grep -q "SE-076 Slice 3" "$SCRIPT"
}

@test "spec ref: AGPL avoidance documented (re-implementation note)" {
  grep -qi "AGPL" "$SCRIPT"
}

@test "safety: llm-healer.sh has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: never invokes git push or merge" {
  ! grep -E '^[^#]*git\s+(push|merge)' "$SCRIPT"
}
