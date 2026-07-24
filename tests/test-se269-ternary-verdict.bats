#!/usr/bin/env bats
# BATS tests for scripts/ternary-verdict.sh (SE-269 S2)
# Ref: docs/specs/SE-269-bmad-patterns.spec.md

SCRIPT="scripts/ternary-verdict.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
}

# ── Structure / safety ────────────────────────────────────────────────────

@test "SE269-S2: script exists and is executable" {
  [[ -x "$SCRIPT" ]]
}

@test "SE269-S2: script has valid bash syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "SE269-S2: --banda is required" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

# ── Banda validation ──────────────────────────────────────────────────────

@test "SE269-S2: validates PASA band" {
  run bash "$SCRIPT" --banda PASA
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "PASA"'* ]]
}

@test "SE269-S2: validates RESERVAS band" {
  run bash "$SCRIPT" --banda RESERVAS --owner "@test" --motivo "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "RESERVAS"'* ]]
}

@test "SE269-S2: validates FALLA band" {
  run bash "$SCRIPT" --banda FALLA --motivo "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "FALLA"'* ]]
}

@test "SE269-S2: validates ENDURECIDA band (S1)" {
  run bash "$SCRIPT" --banda ENDURECIDA --motivo "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "ENDURECIDA"'* ]]
}

@test "SE269-S2: validates MAS_CLARA band (S1)" {
  run bash "$SCRIPT" --banda MAS_CLARA --motivo "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "MAS_CLARA"'* ]]
}

@test "SE269-S2: validates MUERTA band (S1)" {
  run bash "$SCRIPT" --banda MUERTA --motivo "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "MUERTA"'* ]]
}

@test "SE269-S2: validates APROBAR band (S3)" {
  run bash "$SCRIPT" --banda APROBAR
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "APROBAR"'* ]]
}

@test "SE269-S2: validates REHACER band (S3)" {
  run bash "$SCRIPT" --banda REHACER --motivo "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "REHACER"'* ]]
}

@test "SE269-S2: validates SEGUIR band (S3)" {
  run bash "$SCRIPT" --banda SEGUIR --motivo "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "SEGUIR"'* ]]
}

@test "SE269-S2: rejects invalid band" {
  run bash "$SCRIPT" --banda INVALIDO
  [ "$status" -eq 2 ]
}

@test "SE269-S2: normalizes case" {
  run bash "$SCRIPT" --banda pasa
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto": "PASA"'* ]]
}

# ── AC-2.2: Hard gate restriction ─────────────────────────────────────────

@test "SE269-S2 AC-2.2: security gate rejects RESERVAS" {
  run env GATE_TYPE="security" bash "$SCRIPT" --banda RESERVAS --owner "@x" --motivo "test"
  [ "$status" -eq 1 ]
}

@test "SE269-S2 AC-2.2: confidencialidad gate rejects RESERVAS" {
  run env GATE_TYPE="confidencialidad" bash "$SCRIPT" --banda RESERVAS --owner "@x" --motivo "test"
  [ "$status" -eq 1 ]
}

@test "SE269-S2 AC-2.2: linea_roja gate rejects RESERVAS" {
  run env GATE_TYPE="linea_roja" bash "$SCRIPT" --banda RESERVAS --owner "@x" --motivo "test"
  [ "$status" -eq 1 ]
}

@test "SE269-S2 AC-2.2: security gate allows PASA" {
  run env GATE_TYPE="security" bash "$SCRIPT" --banda PASA
  [ "$status" -eq 0 ]
}

@test "SE269-S2 AC-2.2: security gate allows FALLA" {
  run env GATE_TYPE="security" bash "$SCRIPT" --banda FALLA --motivo "test"
  [ "$status" -eq 0 ]
}

# ── AC-2.3: RESERVAS must have owner ──────────────────────────────────────

@test "SE269-S2 AC-2.3: RESERVAS requires --owner" {
  run bash "$SCRIPT" --banda RESERVAS --motivo "test"
  [ "$status" -eq 1 ]
}

@test "SE269-S2 AC-2.3: RESERVAS with owner succeeds" {
  run bash "$SCRIPT" --banda RESERVAS --owner "@test" --motivo "test"
  [ "$status" -eq 0 ]
}

# ── Motivo validation ─────────────────────────────────────────────────────

@test "SE269-S2: non-PASA bands require --motivo" {
  run bash "$SCRIPT" --banda FALLA
  [ "$status" -eq 1 ]
}

@test "SE269-S2: PASA does not require --motivo" {
  run bash "$SCRIPT" --banda PASA
  [ "$status" -eq 0 ]
}

# ── --validate mode ───────────────────────────────────────────────────────

@test "SE269-S2: --validate mode outputs OK" {
  run bash "$SCRIPT" --banda PASA --validate
  [ "$status" -eq 0 ]
  [[ "$output" == "OK: PASA" ]]
}

@test "SE269-S2: --validate mode rejects invalid band" {
  run bash "$SCRIPT" --banda INVALIDO --validate
  [ "$status" -ne 0 ]
}

# ── Dimensiones JSON ──────────────────────────────────────────────────────

@test "SE269-S2: accepts valid --dimensiones JSON" {
  run bash "$SCRIPT" --banda PASA --dimensiones '[{"nombre":"test","banda":"PASA","hallazgos":[]}]'
  [ "$status" -eq 0 ]
}

@test "SE269-S2: rejects invalid --dimensiones JSON" {
  run bash "$SCRIPT" --banda PASA --dimensiones 'not-json'
  [ "$status" -eq 1 ]
}

# ── Output structure ──────────────────────────────────────────────────────

@test "SE269-S2: output contains all required fields" {
  run bash "$SCRIPT" --banda PASA --owner "@test"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"veredicto"'* ]]
  [[ "$output" == *'"motivo"'* ]]
  [[ "$output" == *'"owner"'* ]]
  [[ "$output" == *'"engram_op"'* ]]
  [[ "$output" == *'"origen"'* ]]
  [[ "$output" == *'"timestamp"'* ]]
  [[ "$output" == *'"dimensiones"'* ]]
}

@test "SE269-S2: output is valid JSON" {
  run bash "$SCRIPT" --banda PASA
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool >/dev/null 2>&1
  [ "$?" -eq 0 ]
}
