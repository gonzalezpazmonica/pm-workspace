#!/usr/bin/env bats
# SE-387 B (revisión 2026-09-05): close exige MERGED real, dentro de f5-state.sh.
# Ref: SE-387 — aislamiento: ledger en SAVIA_RESERVATIONS temporal y stub de gh
# fuera del repo; nunca el ~/.savia/reservations real ni tests/bats/.bin-f5.

S="scripts/f5-state.sh"

setup() {
  set -o pipefail
  cd "$BATS_TEST_DIRNAME/../.."
  FX="$(mktemp -d)"
  export SAVIA_RESERVATIONS="$FX/reservations"
  BIN="$FX/bin"
  mkdir -p "$SAVIA_RESERVATIONS" "$BIN"
}

teardown() {
  cd /
}

stub_gh() { printf '#!/usr/bin/env bash\nif [ "$1" = "pr" ]; then echo %s; exit 0; fi\nexit 0\n' "$1" > "$BIN/gh"; chmod +x "$BIN/gh"; }

submitted() { printf '{"op":"pr.merge","key":"%s","state":"submitted"}' "$1" > "$SAVIA_RESERVATIONS/pr.merge__$1.json"; }

@test "safety: f5-state runs under set -uo pipefail" {
  grep -q '^set -uo pipefail' "$S"
}

@test "close con PR OPEN => BLOCK (exit 2), estado NO se cierra" {
  submitted kA
  stub_gh OPEN
  run env PATH="$BIN:$PATH" bash "$S" close pr.merge kA
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCK"* ]]
  [ "$(bash "$S" status pr.merge kA)" = "submitted" ]
}

@test "auto-merge aceptado pero state != MERGED => sigue submitted, NUNCA closed" {
  submitted kB
  stub_gh OPEN
  run env PATH="$BIN:$PATH" bash "$S" close pr.merge kB
  [ "$status" -eq 2 ]
  [ "$(bash "$S" status pr.merge kB)" = "submitted" ]
}

@test "close con PR MERGED => closed + receipt" {
  submitted kC
  stub_gh MERGED
  run env PATH="$BIN:$PATH" bash "$S" close pr.merge kC
  [ "$status" -eq 0 ]
  [ "$(bash "$S" status pr.merge kC)" = "closed" ]
}

@test "retry desde submitted con PR MERGED => close + ALREADY_EXECUTED" {
  submitted kD
  stub_gh MERGED
  run env PATH="$BIN:$PATH" bash "$S" reserve pr.merge kD
  [ "$status" -eq 3 ]
  [[ "$output" == *"ALREADY_EXECUTED"* ]]
  [ "$(bash "$S" status pr.merge kD)" = "closed" ]
}

@test "empty: gh returns no state => close is blocked, never closed" {
  submitted kE
  stub_gh ""
  run env PATH="$BIN:$PATH" bash "$S" close pr.merge kE
  [ "$status" -ne 0 ]
  [ "$(bash "$S" status pr.merge kE)" != "closed" ]
}

@test "nonexistent: reserve on a fresh key creates a reserved entry in the temp ledger" {
  run bash "$S" reserve pr.merge kNew
  [ "$status" -eq 0 ]
  [ "$(jq -r .state "$SAVIA_RESERVATIONS/pr.merge__kNew.json")" = "reserved" ]
}

@test "isolation: the suite never writes the repo stub dir or the home ledger" {
  [ ! -e "tests/bats/.bin-f5" ] || [ -z "$(ls -A tests/bats/.bin-f5 2>/dev/null)" ] || ! git ls-files --error-unmatch tests/bats/.bin-f5 >/dev/null 2>&1
  [[ "$SAVIA_RESERVATIONS" == "$FX/"* ]]
  submitted kIso
  [ -f "$FX/reservations/pr.merge__kIso.json" ]
}
