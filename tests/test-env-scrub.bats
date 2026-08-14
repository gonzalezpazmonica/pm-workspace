#!/usr/bin/env bats
# tests/test-env-scrub.bats — SE-326 S5: env-scrub (AC-S5).
# Ref: docs/propuestas/SE-326-harness-loop-hygiene.md

SCRUB="scripts/env-scrub.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPD="${BATS_TEST_TMPDIR}"
  mkdir -p "$TMPD"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

# ── AC-S5 ─────────────────────────────────────────────────────────────────

@test "S5.1: con SAVIA_SCRUB_ENV=1, run drena *TOKEN*/*SECRET* (AC-S5.1)" {
  export SAVIA_SCRUB_ENV=1
  run env MY_SECRET_TOKEN="leaked" bash "$SCRUB" run env
  [[ ! "$output" == *"MY_SECRET_TOKEN"* ]]
}

@test "S5.2: con SAVIA_SCRUB_ENV unset, no hace nada (AC-S5.2)" {
  unset SAVIA_SCRUB_ENV
  run bash "$SCRUB" check "echo hola"
  [[ $status -eq 0 ]]
}

@test "S5.3: check detecta comando que introduce secret por env (AC-S5.3 warning)" {
  export SAVIA_SCRUB_ENV=1
  run bash "$SCRUB" check 'export API_TOKEN=abc; curl https://x'
  [[ $status -eq 2 ]]
  [[ "$output" == *"WARN [env-scrub]"* ]]
}

@test "S5.4: allowlist PATH/HOME se conserva (AC-S5.1)" {
  export SAVIA_SCRUB_ENV=1
  run bash "$SCRUB" run env
  [[ "$output" == *"PATH="* ]]
  [[ "$output" == *"HOME="* ]]
}

@test "S5.5: --list-dropped lista vars que matchean el patrón (AC-S5.4 telemetría)" {
  export SAVIA_SCRUB_ENV=1
  export MY_GH_TOKEN="x"
  export MY_ORDINARY_VAR="y"
  run bash "$SCRUB" --list-dropped
  [[ "$output" == *"MY_GH_TOKEN"* ]]
  [[ ! "$output" == *"MY_ORDINARY_VAR"* ]]
}
