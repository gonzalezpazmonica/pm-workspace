#!/usr/bin/env bats
# SE-387 C/F5 — exactly-once: retry/crash sobre el mecanismo de reservation.
# Ref: SE-387 — aislamiento: ledger en SAVIA_RESERVATIONS temporal, nunca ~/.savia.

K="bats-test-1"

setup() {
  set -o pipefail
  cd "$BATS_TEST_DIRNAME/../.."
  FX="$(mktemp -d)"
  export SAVIA_RESERVATIONS="$FX/reservations"
  R="$SAVIA_RESERVATIONS"
}

teardown() {
  cd /
}

@test "safety: effect-reservation runs under set -uo pipefail" {
  grep -q '^set -uo pipefail' scripts/effect-reservation.sh
}

@test "F5: reserve crea reservation en estado reserved" {
  run bash scripts/effect-reservation.sh reserve pr.merge "$K"
  [ "$status" -eq 0 ]
  st=$(jq -r .state "$R/pr.merge__$K.json"); [ "$st" = "reserved" ]
}

@test "F5: retry tras crash (reserved sin close) PERMITE completar una vez" {
  bash scripts/effect-reservation.sh reserve pr.merge "$K" >/dev/null
  run bash scripts/effect-reservation.sh reserve pr.merge "$K"
  [ "$status" -eq 0 ]  # reserved (crash previo) permite reintento de completion
}

@test "F5: close + retry => ALREADY_EXECUTED (exit 3, no duplica)" {
  bash scripts/effect-reservation.sh reserve pr.merge "$K" >/dev/null
  bash scripts/effect-reservation.sh close pr.merge "$K" >/dev/null
  run bash scripts/effect-reservation.sh reserve pr.merge "$K"
  [ "$status" -eq 3 ]
  [[ "$output" == *"ALREADY_EXECUTED"* ]]
}

@test "boundary: distinct keys are independent (closing one does not block another)" {
  bash scripts/effect-reservation.sh reserve pr.merge "$K" >/dev/null
  bash scripts/effect-reservation.sh close pr.merge "$K" >/dev/null
  run bash scripts/effect-reservation.sh reserve pr.merge "other-key"
  [ "$status" -eq 0 ]
}

@test "empty: nonexistent ledger dir is created on first reserve" {
  [ ! -d "$R" ]
  run bash scripts/effect-reservation.sh reserve pr.merge "$K"
  [ "$status" -eq 0 ]
  [ -d "$R" ]
}

@test "isolation: reservations land in the temp ledger, not the home ledger" {
  run bash scripts/effect-reservation.sh reserve pr.merge "iso-key"
  [ "$status" -eq 0 ]
  [ -f "$FX/reservations/pr.merge__iso-key.json" ]
  [[ "$R" != "$HOME/.savia/reservations" ]]
}

@test "reject: no arguments prints usage and fails" {
  run bash scripts/effect-reservation.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"uso:"* ]]
}

@test "missing: status of a nonexistent key reports none" {
  run bash scripts/effect-reservation.sh status pr.merge "no-such-key"
  [ "$status" -eq 0 ]
  [ "$output" = "none" ]
}
