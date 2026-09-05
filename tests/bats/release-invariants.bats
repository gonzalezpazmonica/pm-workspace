#!/usr/bin/env bats
# SE-379 — cada fixture rompe exactamente una invariante; ok pasa limpio.
SCRIPT="scripts/release-invariants.sh"
FX="tests/fixtures/release-invariants"

@test "SE-379: fixture ok pasa sin fallos" {
  run bash "$SCRIPT" --root "$FX/ok"
  [ "$status" -eq 0 ]
}

@test "SE-379: fixture version-regression detecta VERSION_REGRESSION" {
  run bash "$SCRIPT" --root "$FX/version-regression"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: VERSION_REGRESSION"* ]]
}

@test "SE-379: fixture changelog-mismatch detecta CHANGELOG_VERSION_MISMATCH" {
  run bash "$SCRIPT" --root "$FX/changelog-mismatch"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: CHANGELOG_VERSION_MISMATCH"* ]]
}

@test "SE-379: fixture stale-counter detecta CAPABILITY_COUNT_MISMATCH" {
  run bash "$SCRIPT" --root "$FX/stale-counter"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: CAPABILITY_COUNT_MISMATCH"* ]]
}

@test "SE-379: fixture stale-translation detecta STALE_TRANSLATION" {
  run bash "$SCRIPT" --root "$FX/stale-translation"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: STALE_TRANSLATION"* ]]
}

@test "SE-379: fixture roadmap-drift detecta ROADMAP_TIMESTAMP_DRIFT" {
  run bash "$SCRIPT" --root "$FX/roadmap-drift"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: ROADMAP_TIMESTAMP_DRIFT"* ]]
}

@test "SE-379: fixture view-drift detecta GENERATED_VIEW_DRIFT" {
  run bash "$SCRIPT" --root "$FX/view-drift"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL: GENERATED_VIEW_DRIFT"* ]]
}
