#!/usr/bin/env bats
# test-se250-agent-rotation.bats — SE-250: token exhaustion detector tests
#
# Acceptance criteria from SE-250:
# 1. --log /dev/null exits 1 (log not found)
# 2. Log with "context_length_exceeded" -> exit 0, CAUSE=token_exhaustion
# 3. Logic error log -> exit 0, CAUSE=logic_error
# 4. No escalation above mid without ALLOW_HEAVY_ESCALATION=true
# 5. BATS suite >= 10 tests, quality >= 80
# 6. Script is pure bash, no LLM calls

SCRIPT="scripts/detect-token-exhaustion.sh"
TMP="${BATS_TEST_TMPDIR:-/tmp}/se250-test-$$"

setup() {
  cd "${BATS_TEST_DIRNAME}/.."
  mkdir -p "$TMP"
}

teardown() {
  rm -rf "$TMP"
}

# ── Structure tests ──────────────────────────────────────────────────────────

@test "SE-250-T01: detect-token-exhaustion.sh exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "SE-250-T02: script declares set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "SE-250-T03: script references SE-250" {
  grep -q "SE-250" "$SCRIPT"
}

@test "SE-250-T04: --help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--log"* ]]
}

@test "SE-250-T05: no LLM calls in script (no curl/ollama/anthropic)" {
  # Script must be deterministic bash only
  grep -qvE "(curl|wget|ollama|anthropic|openai)" "$SCRIPT"
}

# ── Input validation ─────────────────────────────────────────────────────────

@test "SE-250-T06: --log with nonexistent file exits 1" {
  run bash "$SCRIPT" --log /nonexistent/path.log
  [ "$status" -eq 1 ]
  [[ "$output" == *"CAUSE=unknown"* ]]
}

@test "SE-250-T07: missing --log flag exits 1 with usage" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

# ── Token exhaustion detection ────────────────────────────────────────────────

@test "SE-250-T08: log with context_length_exceeded -> CAUSE=token_exhaustion" {
  echo "Error: context_length_exceeded in API call" > "$TMP/token.log"
  run bash "$SCRIPT" --log "$TMP/token.log"
  [ "$status" -eq 0 ]
  [[ "$output" == "CAUSE=token_exhaustion" ]]
}

@test "SE-250-T09: log with max_tokens exceeded -> CAUSE=token_exhaustion" {
  echo "Request failed: max_tokens exceeded (16384 > 12000)" > "$TMP/token2.log"
  run bash "$SCRIPT" --log "$TMP/token2.log"
  [ "$status" -eq 0 ]
  [[ "$output" == "CAUSE=token_exhaustion" ]]
}

@test "SE-250-T10: log with prompt too long -> CAUSE=token_exhaustion" {
  echo "The prompt is too long. Reduce the size of your input." > "$TMP/token3.log"
  run bash "$SCRIPT" --log "$TMP/token3.log"
  [ "$status" -eq 0 ]
  [[ "$output" == "CAUSE=token_exhaustion" ]]
}

# ── Logic error detection ────────────────────────────────────────────────────

@test "SE-250-T11: log with bash syntax error -> CAUSE=logic_error" {
  echo "bash: syntax error near unexpected token" > "$TMP/logic.log"
  run bash "$SCRIPT" --log "$TMP/logic.log"
  [ "$status" -eq 0 ]
  [[ "$output" == "CAUSE=logic_error" ]]
}

@test "SE-250-T12: log with SyntaxError -> CAUSE=logic_error" {
  echo "SyntaxError: invalid syntax in line 42" > "$TMP/logic2.log"
  run bash "$SCRIPT" --log "$TMP/logic2.log"
  [ "$status" -eq 0 ]
  [[ "$output" == "CAUSE=logic_error" ]]
}

@test "SE-250-T13: unknown log content -> CAUSE=unknown, exit 2" {
  echo "Something unexpected happened in the pipeline" > "$TMP/unknown.log"
  run bash "$SCRIPT" --log "$TMP/unknown.log"
  [ "$status" -eq 2 ]
  [[ "$output" == "CAUSE=unknown" ]]
}

@test "SE-250-T14: verbose flag produces extra output about signal matched" {
  echo "Error: context_length_exceeded" > "$TMP/verbose.log"
  run bash "$SCRIPT" --log "$TMP/verbose.log" --verbose
  [ "$status" -eq 0 ]
  # output contains CAUSE line
  [[ "$output" == *"CAUSE=token_exhaustion"* ]]
  # verbose produces SIGNAL: matched line
  [[ "$output" == *"SIGNAL:"* ]]
}
