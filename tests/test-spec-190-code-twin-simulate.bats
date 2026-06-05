#!/usr/bin/env bats
# SCRIPT='scripts/code-twin-simulate.sh'
# test-spec-190-code-twin-simulate.bats — BATS suite for SPEC-190 Slice 5 (simulate)
# Spec: SPEC-190 AC-3, AC-4
# Score target: ≥85 (SPEC-055 quality gate)
# Exercises: symbolic simulation, confidence scoring, db_trace, side_effects,
#            domain errors (INVALID_CREDENTIALS, USER_DISABLED), engine errors

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SIM="$REPO_ROOT/scripts/code-twin-simulate.sh"
SEEDS="$REPO_ROOT/tests/fixtures/code-twin/seeds"

AC3_ARGS='{"email":"alice@test.com","password":"correct"}'
AC4_ARGS='{"email":"notexist@test.com","password":"irrelevant"}'
DISABLED_ARGS='{"email":"charlie@test.com","password":"correct"}'
WRONGPW_ARGS='{"email":"alice@test.com","password":"wrong-password"}'

# ---------------------------------------------------------------------------
# Isolation setup / teardown
# ---------------------------------------------------------------------------

setup() {
  TMP_OUT="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP_OUT"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Run simulator and return only the JSON (lines 2+)
sim_json() {
  bash "$SIM" "$@" | tail -n +2
}

# ---------------------------------------------------------------------------
# Safety verification
# ---------------------------------------------------------------------------

@test "safety: script contains set -uo pipefail" {
  grep -q "set -uo pipefail" "$SIM"
}

@test "safety: output captured correctly to file" {
  bash "$SIM" AuthService login "$AC3_ARGS" "$SEEDS" > "$TMP_OUT/out.txt"
  [ -s "$TMP_OUT/out.txt" ]
}

# ---------------------------------------------------------------------------
# Engine validation
# ---------------------------------------------------------------------------

@test "engine: missing args exits 2" {
  run bash "$SIM"
  [ "$status" -eq 2 ]
}

@test "engine: seeds-dir-not-found exits 2" {
  run bash "$SIM" AuthService login '{"email":"a@b.com","password":"x"}' "/tmp/no-seeds-$$"
  [ "$status" -eq 2 ]
}

@test "engine: unknown module_id exits 2" {
  run bash "$SIM" NoSuchModule login '{"email":"a@b.com","password":"x"}' "$SEEDS"
  [ "$status" -eq 2 ]
}

@test "engine: unknown method exits 2" {
  run bash "$SIM" AuthService noSuchMethod '{"email":"a@b.com","password":"x"}' "$SEEDS"
  [ "$status" -eq 2 ]
}

@test "engine: empty args JSON exits 2" {
  run bash "$SIM" AuthService login '{}' "$SEEDS"
  [ "$status" -eq 2 ]
}

@test "engine: invalid JSON args exits 2" {
  run bash "$SIM" AuthService login 'not-json' "$SEEDS"
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# AC-3: happy path — alice login success
# ---------------------------------------------------------------------------

@test "AC-3: exit 0 on successful login" {
  run bash "$SIM" AuthService login "$AC3_ARGS" "$SEEDS"
  [ "$status" -eq 0 ]
}

@test "AC-3: first output line is simulation header" {
  run bash "$SIM" AuthService login "$AC3_ARGS" "$SEEDS"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"[SIMULATION"* ]]
}

@test "AC-3: header contains NOT GROUND TRUTH" {
  run bash "$SIM" AuthService login "$AC3_ARGS" "$SEEDS"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"NOT GROUND TRUTH"* ]]
}

@test "AC-3: header shows confidence=0.88" {
  run bash "$SIM" AuthService login "$AC3_ARGS" "$SEEDS"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"confidence=0.88"* ]]
}

@test "AC-3: JSON confidence equals 0.88" {
  val=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq '.confidence')
  [ "$val" = "0.88" ]
}

@test "AC-3: JSON confidence >= 0.85" {
  val=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq '.confidence')
  python3 -c "assert $val >= 0.85, '$val < 0.85'"
}

@test "AC-3: output lines 2+ are valid JSON" {
  run bash "$SIM" AuthService login "$AC3_ARGS" "$SEEDS"
  [ "$status" -eq 0 ]
  echo "$output" | tail -n +2 | jq . > /dev/null
}

@test "AC-3: result.token is present and non-empty" {
  token=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.result.token')
  [ -n "$token" ]
  [ "$token" != "null" ]
}

@test "AC-3: result.token starts with sim-token-" {
  token=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.result.token')
  [[ "$token" == sim-token-* ]]
}

@test "AC-3: result.user.id is alice" {
  uid=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.result.user.id')
  [ "$uid" = "sim-alice-001" ]
}

@test "AC-3: result.user.roles is non-empty array" {
  count=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq '.result.user.roles | length')
  [ "$count" -gt 0 ]
}

@test "AC-3: db_trace has exactly 2 ops" {
  count=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq '.db_trace | length')
  [ "$count" -eq 2 ]
}

@test "AC-3: db_trace first op is READ" {
  op=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.db_trace[0].op')
  [ "$op" = "READ" ]
}

@test "AC-3: db_trace first op table is users" {
  tbl=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.db_trace[0].table')
  [ "$tbl" = "users" ]
}

@test "AC-3: db_trace second op is WRITE" {
  op=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.db_trace[1].op')
  [ "$op" = "WRITE" ]
}

@test "AC-3: db_trace WRITE table is users" {
  tbl=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.db_trace[1].table')
  [ "$tbl" = "users" ]
}

@test "AC-3: db_trace WRITE fields include last_login_at" {
  result=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.db_trace[1].fields | contains(["last_login_at"])')
  [ "$result" = "true" ]
}

@test "AC-3: side_effects is non-empty" {
  count=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq '.side_effects | length')
  [ "$count" -gt 0 ]
}

@test "AC-3: side_effects[0] mentions last_login_at" {
  se=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.side_effects[0]')
  [[ "$se" == *"last_login_at"* ]]
}

@test "AC-3: execution time under 3 seconds" {
  start=$SECONDS
  bash "$SIM" AuthService login "$AC3_ARGS" "$SEEDS" > /dev/null
  elapsed=$(( SECONDS - start ))
  [ "$elapsed" -lt 3 ]
}

# ---------------------------------------------------------------------------
# AC-4: user not found → INVALID_CREDENTIALS 401
# ---------------------------------------------------------------------------

@test "AC-4: exits 1 on not-found user" {
  run bash "$SIM" AuthService login "$AC4_ARGS" "$SEEDS"
  [ "$status" -eq 1 ]
}

@test "AC-4: header present even on error" {
  run bash "$SIM" AuthService login "$AC4_ARGS" "$SEEDS"
  [[ "${lines[0]}" == *"NOT GROUND TRUTH"* ]]
}

@test "AC-4: error.code is INVALID_CREDENTIALS" {
  code=$(sim_json AuthService login "$AC4_ARGS" "$SEEDS" | jq -r '.error.code')
  [ "$code" = "INVALID_CREDENTIALS" ]
}

@test "AC-4: error.status is 401" {
  status=$(sim_json AuthService login "$AC4_ARGS" "$SEEDS" | jq '.error.status')
  [ "$status" -eq 401 ]
}

@test "AC-4: result is null" {
  result=$(sim_json AuthService login "$AC4_ARGS" "$SEEDS" | jq '.result')
  [ "$result" = "null" ]
}

@test "AC-4: db_trace has exactly 1 op (READ only, no WRITE)" {
  count=$(sim_json AuthService login "$AC4_ARGS" "$SEEDS" | jq '.db_trace | length')
  [ "$count" -eq 1 ]
}

@test "AC-4: db_trace single op is READ" {
  op=$(sim_json AuthService login "$AC4_ARGS" "$SEEDS" | jq -r '.db_trace[0].op')
  [ "$op" = "READ" ]
}

@test "AC-4: side_effects is empty array" {
  count=$(sim_json AuthService login "$AC4_ARGS" "$SEEDS" | jq '.side_effects | length')
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Disabled user edge case
# ---------------------------------------------------------------------------

@test "disabled: exits 1" {
  run bash "$SIM" AuthService login "$DISABLED_ARGS" "$SEEDS"
  [ "$status" -eq 1 ]
}

@test "disabled: error.code is USER_DISABLED" {
  code=$(sim_json AuthService login "$DISABLED_ARGS" "$SEEDS" | jq -r '.error.code')
  [ "$code" = "USER_DISABLED" ]
}

@test "disabled: error.status is 403" {
  status=$(sim_json AuthService login "$DISABLED_ARGS" "$SEEDS" | jq '.error.status')
  [ "$status" -eq 403 ]
}

@test "disabled: db_trace has 1 READ and no WRITE" {
  count=$(sim_json AuthService login "$DISABLED_ARGS" "$SEEDS" | jq '.db_trace | length')
  [ "$count" -eq 1 ]
}

@test "disabled: side_effects is empty" {
  count=$(sim_json AuthService login "$DISABLED_ARGS" "$SEEDS" | jq '.side_effects | length')
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Wrong password edge case
# ---------------------------------------------------------------------------

@test "wrong-password: exits 1" {
  run bash "$SIM" AuthService login "$WRONGPW_ARGS" "$SEEDS"
  [ "$status" -eq 1 ]
}

@test "wrong-password: error.code is INVALID_CREDENTIALS" {
  code=$(sim_json AuthService login "$WRONGPW_ARGS" "$SEEDS" | jq -r '.error.code')
  [ "$code" = "INVALID_CREDENTIALS" ]
}

@test "wrong-password: db_trace has 1 READ (no WRITE)" {
  count=$(sim_json AuthService login "$WRONGPW_ARGS" "$SEEDS" | jq '.db_trace | length')
  [ "$count" -eq 1 ]
}

@test "wrong-password: side_effects is empty" {
  count=$(sim_json AuthService login "$WRONGPW_ARGS" "$SEEDS" | jq '.side_effects | length')
  [ "$count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Output structure invariants
# ---------------------------------------------------------------------------

@test "output: module_id in JSON matches input" {
  mid=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.module_id')
  [ "$mid" = "AuthService" ]
}

@test "output: method in JSON matches input" {
  mth=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq -r '.method')
  [ "$mth" = "login" ]
}

@test "output: confidence key present in all paths" {
  result=$(sim_json AuthService login "$AC4_ARGS" "$SEEDS" | jq 'has("confidence")')
  [ "$result" = "true" ]
}

@test "output: confidence is never 1.0 on success" {
  conf=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | jq '.confidence')
  python3 -c "assert $conf < 1.0, 'confidence must never be 1.0'"
}

@test "output: confidence is never 1.0 on error paths" {
  conf=$(sim_json AuthService login "$AC4_ARGS" "$SEEDS" | jq '.confidence')
  python3 -c "assert $conf < 1.0, 'confidence must never be 1.0'"
}

@test "output: db_trace entries have op and table fields" {
  result=$(sim_json AuthService login "$AC3_ARGS" "$SEEDS" | \
    jq '[.db_trace[] | has("op") and has("table")] | all')
  [ "$result" = "true" ]
}
