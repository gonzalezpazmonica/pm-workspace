#!/usr/bin/env bats
# tests/test-criterion-simulation-hook.bats — SPEC-194 Criterion Simulation Layer
#
# Tests for .opencode/hooks/criterion-simulation-challenge.sh
#
# AC1:  Banner contains "simulacion de meta-reflexion, no tu criterio"
# AC2:  Exit 0 ALWAYS in all 3 verdicts (FRAME_OK, FRAME_DOUBT, FRAME_REJECT)
# AC9:  Telemetry JSONL is valid
# AC10: Mode shadow never emits to stderr
# AC11: Mode advise emits banner but does not require reaffirmation
# AC12: Mode interrupt emits banner AND logs reaffirmation_required=true
# AC13: SAVIA_CRITERION_SIMULATION=off silences everything

BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(dirname "$0")}"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOOK="$REPO_ROOT/.opencode/hooks/criterion-simulation-challenge.sh"
  export CLAUDE_PROJECT_DIR="$REPO_ROOT"

  # Temp dir for output isolation
  export TMPDIR_CS
  TMPDIR_CS="$(mktemp -d)"
  export SAVIA_CS_LOG="${TMPDIR_CS}/events.jsonl"

  # High-impact task JSON (touches_security + touches_production = score 55 >= 50)
  export HIGH_IMPACT_JSON='{"touches_security":true,"touches_production":true,"problem_statement":"patch auth","proposed_solution":"disable check"}'

  # Default: master switch ON for most tests
  export SAVIA_CRITERION_SIMULATION=on

  # Default mock verdict (bypass real LLM judge)
  unset SAVIA_CS_MOCK_VERDICT
}

teardown() {
  rm -rf "$TMPDIR_CS"
  unset SAVIA_CRITERION_SIMULATION SAVIA_CS_MODE SAVIA_CS_MOCK_VERDICT SAVIA_CS_LOG HIGH_IMPACT_JSON
}

# ── Helper: build a mock verdict JSON ─────────────────────────────────────────
mk_verdict() {
  local verdict="${1:-FRAME_OK}"
  local banner="${2:-This is a simulated banner for testing.}"
  printf '{"verdict":"%s","banner_text":"%s","confidence":0.5,"is_simulation_disclaimer":"soy simulacion de meta-reflexion, no tu criterio. Tu decides.","tokens_used":100}' \
    "$verdict" "$banner"
}

# ─────────────────────────────────────────────────────────────────────────────
# AC13: Master switch off
# ─────────────────────────────────────────────────────────────────────────────

@test "AC13: SAVIA_CRITERION_SIMULATION=off exits 0 silently" {
  export SAVIA_CRITERION_SIMULATION=off
  export SAVIA_CS_MODE=interrupt
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_REJECT 'critical frame issue')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "AC13: SAVIA_CRITERION_SIMULATION=off no telemetry written" {
  export SAVIA_CRITERION_SIMULATION=off
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ ! -f "$SAVIA_CS_LOG" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC2: Exit 0 always
# ─────────────────────────────────────────────────────────────────────────────

@test "AC2: FRAME_OK exits 0" {
  export SAVIA_CS_MODE=advise
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_OK '')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "AC2: FRAME_DOUBT exits 0 (advise mode)" {
  export SAVIA_CS_MODE=advise
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_DOUBT 'Frame may not match real problem.')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "AC2: FRAME_REJECT exits 0 (advise mode)" {
  export SAVIA_CS_MODE=advise
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_REJECT 'Strong frame mismatch detected.')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "AC2: FRAME_REJECT exits 0 (interrupt mode)" {
  export SAVIA_CS_MODE=interrupt
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_REJECT 'Strong frame mismatch detected.')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "AC2: FRAME_DOUBT exits 0 (interrupt mode)" {
  export SAVIA_CS_MODE=interrupt
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_DOUBT 'Frame may not match real problem.')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC10: Shadow mode — no stderr
# ─────────────────────────────────────────────────────────────────────────────

@test "AC10: shadow mode FRAME_DOUBT does not emit to stderr" {
  export SAVIA_CS_MODE=shadow
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_DOUBT 'Frame issue')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK' 2>&1"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"criterion-simulation SPEC-194"* ]]
}

@test "AC10: shadow mode FRAME_REJECT does not emit to stderr" {
  export SAVIA_CS_MODE=shadow
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_REJECT 'Frame reject')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK' 2>&1"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"criterion-simulation SPEC-194"* ]]
}

@test "AC10: shadow mode FRAME_OK does not emit to stderr" {
  export SAVIA_CS_MODE=shadow
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_OK '')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK' 2>&1"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"criterion-simulation SPEC-194"* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC1 + AC11: Advise mode banner + disclaimer
# ─────────────────────────────────────────────────────────────────────────────

@test "AC11: advise mode FRAME_DOUBT emits banner to stderr" {
  export SAVIA_CS_MODE=advise
  local banner="Frame may not match the real underlying problem."
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_DOUBT "$banner")"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK' 2>&1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"criterion-simulation SPEC-194"* ]]
}

@test "AC1: advise mode banner contains disclaimer phrase" {
  export SAVIA_CS_MODE=advise
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_DOUBT 'Q1 possible frame drift detected.')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK' 2>&1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"simulacion de meta-reflexion, no tu criterio"* ]]
}

@test "AC1: advise mode FRAME_REJECT banner contains disclaimer" {
  export SAVIA_CS_MODE=advise
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_REJECT 'Strong mismatch: solution does not match problem.')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK' 2>&1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"simulacion de meta-reflexion, no tu criterio"* ]]
}

@test "AC11: advise mode FRAME_OK does NOT emit banner" {
  export SAVIA_CS_MODE=advise
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_OK '')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK' 2>&1"
  [[ "$status" -eq 0 ]]
  [[ "$output" != *"criterion-simulation SPEC-194"* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC12: Interrupt mode — banner + reaffirmation_required=true in log
# ─────────────────────────────────────────────────────────────────────────────

@test "AC12: interrupt mode FRAME_DOUBT emits banner" {
  export SAVIA_CS_MODE=interrupt
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_DOUBT 'Frame issue in interrupt mode')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK' 2>&1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"criterion-simulation SPEC-194"* ]]
}

@test "AC12: interrupt mode logs reaffirmation_required=true" {
  export SAVIA_CS_MODE=interrupt
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_DOUBT 'Frame issue requires reaffirmation')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]

  # Log file should exist
  [[ -f "$SAVIA_CS_LOG" ]]

  # At least one entry should have reaffirmation_required=true
  local found=0
  while IFS= read -r line; do
    if command -v jq >/dev/null 2>&1; then
      req=$(echo "$line" | jq -r '.reaffirmation_required // false' 2>/dev/null)
      if [[ "$req" == "true" ]]; then
        found=1
        break
      fi
    else
      # fallback grep
      if echo "$line" | grep -q '"reaffirmation_required":true'; then
        found=1
        break
      fi
    fi
  done < "$SAVIA_CS_LOG"

  [[ "$found" -eq 1 ]]
}

@test "AC12: interrupt mode FRAME_REJECT logs reaffirmation_required=true" {
  export SAVIA_CS_MODE=interrupt
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_REJECT 'Reject: strong frame mismatch')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ -f "$SAVIA_CS_LOG" ]]

  local found=0
  while IFS= read -r line; do
    if echo "$line" | grep -q 'reaffirmation_required'; then
      found=1
      break
    fi
  done < "$SAVIA_CS_LOG"
  [[ "$found" -eq 1 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# AC9: Telemetry JSONL valid
# ─────────────────────────────────────────────────────────────────────────────

@test "AC9: shadow mode writes valid JSONL telemetry" {
  command -v jq >/dev/null 2>&1 || skip "jq not available for JSONL validation"
  export SAVIA_CS_MODE=shadow
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_DOUBT 'Frame issue')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ -f "$SAVIA_CS_LOG" ]]

  # Every non-empty line must be valid JSON with required fields
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line" | jq -e '.ts' >/dev/null 2>&1
    echo "$line" | jq -e '.verdict' >/dev/null 2>&1
    echo "$line" | jq -e '.mode' >/dev/null 2>&1
  done < "$SAVIA_CS_LOG"
}

@test "AC9: advise mode telemetry entry has ts field" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"
  export SAVIA_CS_MODE=advise
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_DOUBT 'Frame issue')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
  [[ -f "$SAVIA_CS_LOG" ]]

  # Check at least one entry has ts
  local has_ts=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if echo "$line" | jq -e '.ts' >/dev/null 2>&1; then
      has_ts=1
      break
    fi
  done < "$SAVIA_CS_LOG"
  [[ "$has_ts" -eq 1 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Edge cases
# ─────────────────────────────────────────────────────────────────────────────

@test "no stdin exits 0 (low-impact task bypassed)" {
  export SAVIA_CS_MODE=advise
  unset SAVIA_CS_MOCK_VERDICT
  run bash "$HOOK" < /dev/null
  [[ "$status" -eq 0 ]]
}

@test "invalid JSON input exits 0 gracefully" {
  export SAVIA_CS_MODE=advise
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_REJECT 'issue')"
  run bash -c "printf 'not json' | bash '$HOOK'"
  [[ "$status" -eq 0 ]]
}

@test "unknown mode falls back to advise" {
  export SAVIA_CS_MODE=unknown_mode
  export SAVIA_CS_MOCK_VERDICT="$(mk_verdict FRAME_DOUBT 'Frame issue')"
  run bash -c "printf '%s' '$HIGH_IMPACT_JSON' | bash '$HOOK' 2>&1"
  [[ "$status" -eq 0 ]]
}
