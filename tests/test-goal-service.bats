#!/usr/bin/env bats
# tests/test-goal-service.bats — SE-326 S4: goal-service (AC-S4).
# Ref: docs/propuestas/SE-326-harness-loop-hygiene.md

SERVICE="scripts/goal-service.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPD="${BATS_TEST_TMPDIR}"
  export GOAL_STATE_ROOT="$TMPD/goals"
  mkdir -p "$TMPD"
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
  cd /
}

# ── AC-S4 ─────────────────────────────────────────────────────────────────

@test "S4.1: create → fase active, revision 1, round 0 (AC-S4.1)" {
  run bash "$SERVICE" sess1 create --objective "terminar SE-326"
  [[ "$output" =~ '"phase": "active"' ]]
  [[ "$output" =~ '"revision": 1' ]]
  [[ "$output" =~ '"rounds_started": 0' ]]
}

@test "S4.2: mutación con ref desactualizado → version-conflict (AC-S4.2)" {
  out=$(bash "$SERVICE" sess2 create --objective "objetivo A")
  ID=$(echo "$out" | python3 -c "import json,sys;print(json.load(sys.stdin)['goal']['id'])")
  bash "$SERVICE" sess2 edit "$ID" 1 --objective "objetivo B" >/dev/null
  run bash "$SERVICE" sess2 complete "$ID" 1
  [[ $status -eq 3 ]]
  [[ "$output" =~ 'version-conflict' ]]
}

@test "S4.3: round-cap alcanzado → blocked round-cap-reached (AC-S4.3)" {
  out=$(bash "$SERVICE" sess3 create --objective "objetivo" --max-goal-rounds 2)
  ID=$(echo "$out" | python3 -c "import json,sys;print(json.load(sys.stdin)['goal']['id'])")
  bash "$SERVICE" sess3 admit-round "$ID" 1 >/dev/null
  bash "$SERVICE" sess3 admit-round "$ID" 2 >/dev/null
  run bash "$SERVICE" sess3 admit-round "$ID" 3
  [[ "$output" =~ 'round-cap-reached' ]]
  [[ "$output" =~ '"phase": "blocked"' ]]
}

@test "S4.4: block exige code y message (AC-S4.4)" {
  out=$(bash "$SERVICE" sess4 create --objective "objetivo")
  ID=$(echo "$out" | python3 -c "import json,sys;print(json.load(sys.stdin)['goal']['id'])")
  run bash "$SERVICE" sess4 block "$ID" 1
  [[ $status -eq 5 ]]
  run bash "$SERVICE" sess4 block "$ID" 1 --code blocked-by-user --message "pausa manual"
  [[ "$output" =~ '"code": "blocked-by-user"' ]]
  [[ "$output" =~ '"phase": "blocked"' ]]
}

@test "S4.5: clear retiene tombstone, id no se reutiliza (AC-S4.5)" {
  out=$(bash "$SERVICE" sess5 create --objective "objetivo")
  ID=$(echo "$out" | python3 -c "import json,sys;print(json.load(sys.stdin)['goal']['id'])")
  run bash "$SERVICE" sess5 clear "$ID" 1
  [[ "$output" =~ 'tombstone' ]]
  out2=$(bash "$SERVICE" sess5 create --objective "segundo")
  ID2=$(echo "$out2" | python3 -c "import json,sys;print(json.load(sys.stdin)['goal']['id'])")
  [[ "$ID2" -gt "$ID" ]]
}

@test "S4.6: no se puede crear goal si hay uno activo (fase no complete)" {
  bash "$SERVICE" sess6 create --objective "primero" >/dev/null
  run bash "$SERVICE" sess6 create --objective "segundo"
  [[ $status -eq 5 ]]
}

@test "S4.7: estado durable fuera del repo (AC-S4.7)" {
  bash "$SERVICE" sess7 create --objective "objetivo" >/dev/null
  [[ -f "$TMPD/goals/sess7.json" ]]
}
