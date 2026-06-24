#!/usr/bin/env bats
# tests/test-se224-verbosity-sentinel.bats
# SE-224 Slice 1 — verbosity sentinel hook tests
# Ref: docs/propuestas/SE-224-headroom-effort-routing-verbosity.md

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  HOOK="$PWD/.opencode/hooks/output-verbosity-sentinel.sh"
  CAVEMAN_DOC="$PWD/docs/rules/domain/caveman-default.md"
}

# ── AC1: hook is executable and has set -uo pipefail ────────────────────────

@test "AC1: hook is executable" {
  [[ -x "$HOOK" ]]
}

@test "AC1: hook has set -uo pipefail" {
  grep -q "set -uo pipefail" "$HOOK"
}

# ── AC2: clean tool_result → L2 ─────────────────────────────────────────────

@test "AC2: clean tool_result (TOOL_NAME set, no error) emits L2" {
  run env TOOL_NAME="Read" TOOL_ERROR="" bash "$HOOK" <<<"" 
  # sentinel is emitted on stderr; 'run' captures stdout; check stderr via output
  [[ "$status" -eq 0 ]]
  # Re-run capturing stderr explicitly
  ERR="$(env TOOL_NAME="Read" TOOL_ERROR="" bash "$HOOK" <<<'' 2>&1 >/dev/null)"
  [[ "$ERR" == *'"verbosityLevel":"L2"'* ]]
}

@test "AC2: clean tool_result emits MECHANICAL turn class" {
  ERR="$(env TOOL_NAME="Bash" TOOL_ERROR="" bash "$HOOK" <<<'' 2>&1 >/dev/null)"
  [[ "$ERR" == *'"turnClass":"MECHANICAL"'* ]]
}

# ── AC3: error tool_result → L1 ─────────────────────────────────────────────

@test "AC3: tool_result with is_error=true emits L1" {
  ERR="$(env TOOL_NAME="Bash" TOOL_ERROR="true" bash "$HOOK" <<<'' 2>&1 >/dev/null)"
  [[ "$ERR" == *'"verbosityLevel":"L1"'* ]]
}

@test "AC3: tool_result with is_error=true emits ERROR turn class" {
  ERR="$(env TOOL_NAME="Bash" TOOL_ERROR="true" bash "$HOOK" <<<'' 2>&1 >/dev/null)"
  [[ "$ERR" == *'"turnClass":"ERROR"'* ]]
}

# ── AC4: user message (no TOOL_NAME) → L1 ───────────────────────────────────

@test "AC4: no TOOL_NAME (user message) emits L1" {
  ERR="$(env -u TOOL_NAME bash "$HOOK" <<<'{"type":"user_message","content":"hello"}' 2>&1 >/dev/null)"
  [[ "$ERR" == *'"verbosityLevel":"L1"'* ]]
}

@test "AC4: no TOOL_NAME emits NEW_ASK turn class" {
  ERR="$(env -u TOOL_NAME bash "$HOOK" <<<'' 2>&1 >/dev/null)"
  [[ "$ERR" == *'"turnClass":"NEW_ASK"'* ]]
}

# ── AC5: hook never blocks ───────────────────────────────────────────────────

@test "AC5: hook exits 0 with clean input" {
  run env TOOL_NAME="Read" bash "$HOOK" <<<"valid content"
  [ "$status" -eq 0 ]
}

@test "AC5: hook exits 0 with empty input" {
  run env -u TOOL_NAME bash "$HOOK" <<<""
  [ "$status" -eq 0 ]
}

@test "AC5: hook exits 0 with malformed JSON input" {
  run env TOOL_NAME="Write" bash "$HOOK" <<<"not json at all"
  [ "$status" -eq 0 ]
}

# ── AC6: caveman-default.md references SE-224 ────────────────────────────────

@test "AC6: caveman-default.md mentions SE-224" {
  grep -q "SE-224" "$CAVEMAN_DOC"
}

@test "AC6: caveman-default.md mentions VERBOSITY_LEVEL tag" {
  grep -q "VERBOSITY_LEVEL" "$CAVEMAN_DOC"
}

@test "AC6: caveman-default.md mentions prefix cache" {
  grep -q "prefix cache" "$CAVEMAN_DOC"
}

# ── AC7: idempotency tag format ──────────────────────────────────────────────

@test "AC7: sentinel output contains idempotency tag <!-- VERBOSITY_LEVEL:L2 -->" {
  ERR="$(env TOOL_NAME="Read" TOOL_ERROR="" bash "$HOOK" <<<'' 2>&1 >/dev/null)"
  [[ "$ERR" == *'<!-- VERBOSITY_LEVEL:L2 -->'* ]]
}

@test "AC7: sentinel output is valid JSON" {
  ERR="$(env TOOL_NAME="Read" TOOL_ERROR="" bash "$HOOK" <<<'' 2>&1 >/dev/null)"
  # Basic JSON structure check: starts with { ends with }
  [[ "$ERR" == "{"* ]]
  [[ "$ERR" == *"}" ]]
}

@test "AC7: sentinel includes spec reference SE-224" {
  ERR="$(env TOOL_NAME="Read" TOOL_ERROR="" bash "$HOOK" <<<'' 2>&1 >/dev/null)"
  [[ "$ERR" == *'"spec":"SE-224"'* ]]
}
