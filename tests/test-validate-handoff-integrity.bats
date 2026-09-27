#!/usr/bin/env bats
# Ref: SE-387 C/F3 — handoff integrity (refs + checksums + required fields).
# The validator had no tests; it had also overwritten validate-handoff.sh
# (SPEC-TERMINAL-STATE-HANDOFF) until 2026-09-27.

SCRIPT="scripts/validate-handoff-integrity.sh"

setup() {
  set -o pipefail
  cd "$BATS_TEST_DIRNAME/.."
  FX="$(mktemp -d)"
  SUM="$(sha256sum README.md | cut -d' ' -f1)"
}

teardown() {
  cd /
}

handoff() { # <refs-json> <checksums-json> [extra-jq]
  jq -n --argjson r "$1" --argjson c "$2" \
    '{source_agent:"a",target_agent:"b",scope:"s",artifact_refs:$r,checksums:$c}' > "$FX/h.json"
}

@test "safety: validator runs under set -uo pipefail" {
  grep -q '^set -uo pipefail' "$SCRIPT"
}

@test "positive: intact handoff with a verified checksum passes" {
  handoff '["README.md"]' "{\"README.md\":\"$SUM\"}"
  run bash "$SCRIPT" "$FX/h.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS: handoff íntegro (1 refs)"* ]]
}

@test "positive: http refs are not resolved on disk" {
  handoff '["https://example.com/x","README.md"]' '{}'
  run bash "$SCRIPT" "$FX/h.json"
  [ "$status" -eq 0 ]
}

@test "reject: a missing artifact ref fails" {
  handoff '["docs/does-not-exist.md"]' '{}'
  run bash "$SCRIPT" "$FX/h.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ref desaparecida docs/does-not-exist.md"* ]]
}

@test "reject: a wrong checksum is HANDOFF_INVALID" {
  handoff '["README.md"]' '{"README.md":"0000"}'
  run bash "$SCRIPT" "$FX/h.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"HANDOFF_INVALID: checksum README.md"* ]]
}

@test "missing: required fields absent fails" {
  printf '{"artifact_refs":[]}\n' > "$FX/h.json"
  run bash "$SCRIPT" "$FX/h.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"sin campos obligatorios"* ]]
}

@test "nonexistent: handoff file that does not exist fails" {
  run bash "$SCRIPT" "$FX/nope.json"
  [ "$status" -eq 1 ]
  [[ "$output" == *"handoff no existe"* ]]
}

@test "empty: handoff with no artifact refs passes with 0 refs" {
  handoff '[]' '{}'
  run bash "$SCRIPT" "$FX/h.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(0 refs)"* ]]
}

@test "regression: validate-handoff.sh is the terminal-state validator again" {
  grep -q 'SPEC-TERMINAL-STATE-HANDOFF' scripts/validate-handoff.sh
  grep -q 'SE-387 C/F3' "$SCRIPT"
}
